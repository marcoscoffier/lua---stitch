require 'xlua'
require 'image'
require 'libstitch'

local Stitcher = torch.class('stitcher')

function Stitcher:__init()
   -- need to move initialization into get info function
   self.nimages    = 4
   self.imgsize    = {1280,960}
   -- self.canvassize = {2588,892}
   self.panocrop   = {0,2588,245,731}
   self.panosize   = {self.panocrop[2]-self.panocrop[1],
                      self.panocrop[4]-self.panocrop[3]}
   self.panomidpt  = self.panosize[1]/2
   self.index    = torch.Tensor(3,self.panosize[2],self.panosize[1])
   self.panorama = torch.Tensor(3,self.panosize[2],self.panosize[1])
end

-- extract all necessary information from .pto file
function Stitcher:get_info()
end

-- wrapper to the command line hugin tool pano_trafo to make index
-- maps for all images in a .pto file
function Stitcher:make_maps()
end

function Stitcher:load_index(fname)
   local f = torch.DiskFile(fname,'r')
   f:binary()
   self.index = f:readObject()
   f:close()
end

function Stitcher:save_index(fname)
   local f = torch.DiskFile(fname,'w')
   f:binary()
   f:writeObject(self.index)
   f:close()
end

-- from a bunch of maps (torch.Files) produced with make_maps(),
-- create a single index self.index
function Stitcher:make_index(maps)
   sys.tic()
   local ipatches = {}
   local img_maxw = {}
   local img_minw = {}
   local wrapped_image = false
   local wrapped_image_no = 0

   -- loops through the images and creates an index size of the panorama
   -- with only the indexes to that image.
   for i = 1,self.nimages do 
      ipatches[i] = torch.Tensor(2,self.panosize[2],self.panosize[1])
      maps[i]:seek(1)
      local ixy = ipatches[i]
      if not img_maxw[i] then img_maxw[i] = -math.huge end
      if not img_minw[i] then img_minw[i] =  math.huge end
      for x = 1,self.imgsize[1] do 
         for y = 1,self.imgsize[2] do
            local px = math.floor(maps[i]:readFloat() + 0.5)
            local py = math.floor(maps[i]:readFloat() + 0.5)
            if (((px > self.panocrop[1]) and (px <= self.panocrop[2])) 
             and 
             ((py > self.panocrop[3]) and (py <= self.panocrop[4]))) then
               if wrapped_image then
                  -- reverse max and min
                  if px > self.panomidpt then 
                     -- over midpoint 
                     if px < img_minw[i] then img_minw[i] = px end
                  else
                     if px > img_maxw[i] then img_maxw[i] = px end
                  end
               else
                  if px > img_maxw[i] then img_maxw[i] = px end
                  if img_maxw[i] >= self.panocrop[2]-1 then 
                     wrapped_image = true 
                     img_maxw[i] = -math.huge
                  end
                  if px < img_minw[i] then img_minw[i] = px end
                  if img_minw[i] <= self.panocrop[1]+1 then 
                     wrapped_image = true 
                     img_minw[i] = math.huge
                  end
               end
               local ipy = py-self.panocrop[3]
               local ipx = px-self.panocrop[1]
               -- fill index
               ixy[1][ipy][ipx] = y
               ixy[2][ipy][ipx] = x
            end
         end
      end
      if wrapped_image then
         wrapped_image_no = i
         wrapped_image = false
      end
   end
   print("Read and map images to patches: "..sys.toc())
   print(img_maxw)
   print(img_minw)
   sys.tic()
   if wrapped_image_no > 1 then 
      self.index:select(1,1):fill(wrapped_image_no)
      self.index:narrow(1,2,2):copy(ipatches[wrapped_image_no])
   end

   -- find boundaries.  Given the stored max and min index for each
   -- image.  compute overlaps and copy index to final panorama
   -- loops through all the image maps and find the overlaps.  Picks 1/2
   -- way point of overlap to switch input images in the output.  Assumes
   -- horizonal sequential images, so not very general
   for i = 1,self.nimages do
      if (wrapped_image_no > 1) and (not (i == wrapped_image_no)) then
         local prev = i-1
         local next = i+1
         local crop_min   = 0
         local crop_max   = 0
         local crop_width = 0
         local overlap_left  = 0
         local overlap_right = 0
         if prev < 1 then prev = self.nimages end
         if next > self.nimages then next = 1 end
         overlap_min = (img_maxw[prev] - img_minw[i]) / 2
         overlap_max = (img_maxw[i] - img_minw[next]) / 2
         crop_left   =  img_minw[i] + overlap_min
         crop_right  =  img_maxw[i] - overlap_max
         crop_width  =  crop_right  - crop_left
         print("fill index with",i)
         self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
         self.index:narrow(1,2,2):narrow(3,crop_left,crop_width):copy(ipatches[i]:narrow(3,crop_left,crop_width))
      end
   end
   print("created index"..sys.toc())
end



function Stitcher:stitch (img, pano)
   local pano = pano or self.panorama
   pano:resizeAs(self.index)
   for i = 1,self.panosize[2] do 
      for j = 1,self.panosize[1] do
         local imgidx = self.index[1][i][j]
         local yidx   = self.index[2][i][j]
         local xidx   = self.index[3][i][j]
         if xidx > 0 and xidx <= self.imgsize[1] and 
            yidx > 0 and yidx <= self.imgsize[2] then
            pano:select(3,j):select(2,i):copy(img[imgidx]:select(3,xidx):select(2,yidx))
         end
      end 
   end
end

function Stitcher:stitch_c ()
   -- pano.resize()
   libstitch.stitch(imgiouput,ioutput,img)
end