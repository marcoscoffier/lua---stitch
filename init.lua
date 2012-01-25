require 'xlua'
require 'image'
require 'torch'
require 'libstitch'

local Stitcher = torch.class('stitcher')

function Stitcher:__init(pto_file)
   if not pto_file then
      error("You must pass a .pto file (output of hugin or panotools)")
   end
   self.pto_file   = pto_file
   -- need to move initialization into get info function
   self.nimages    = 0
   self.imgwidth   = {}
   self.imgheight  = {}
   self.canvassize = {}
   self.panocrop   = {}

   -- process pto file (open for reading in quiet mode)
   local f = torch.DiskFile(pto_file,'r',true)
   local s = f:readString('*l')
   
   local function exec( s )
      return loadstring( 'return ' .. s )()
   end

   while s do 
      -- find panorama line
      if s:match("^p ") then
         local w = s:match(" w%d+"):gsub(" w","")
         local h = s:match(" h%d+"):gsub(" h","")
         self.canvassize = { w , h }
         local crop = s:match(" S%d+,%d+,%d+,%d+"):gsub(" S","")
         crop = exec  ('{'..crop..'}')
         self.panocrop = crop
         -- find image lines
      elseif s:match("^i ") then
         self.nimages = self.nimages + 1
         local w = s:match(" w%d+"):gsub(" w","")
         local h = s:match(" h%d+"):gsub(" h","")
         table.insert(self.imgwidth, w)
         table.insert(self.imgheight, h)
      end 
      s = f:readString('*l') 
      if f:hasError() then 
         f:close()
         s = false
      end
   end
   -- actual size of panorama produced is based on crop
   self.panosize   = {self.panocrop[2]-self.panocrop[1],
                      self.panocrop[4]-self.panocrop[3]}
   self.panomidpt  = self.panosize[1]/2
   self.index    = torch.Tensor(3,self.panosize[2],self.panosize[1])
   self.panorama = torch.Tensor(3,self.panosize[2],self.panosize[1])
end

-- extract all necessary information from .pto file
function Stitcher:get_info(fname)
   local f = torch.DiskFile(fname,'r')
   f:ascii() 
end

-- wrapper to the command line hugin tool pano_trafo to make index
-- maps for all images in a .pto file
function Stitcher:make_maps()
   local maps = {}
   for i = 1,self.nimages do 
      local cmd = string.format("for x in `seq 1 %d` ; do for y in `seq 1 %d` ; do echo %d $x $y ; done ;done | pano_trafo %s",
                                self.imgwidth[i],self.imgheight[i],
                                i-1,self.pto_file)
      maps[i] = torch.PipeFile(cmd,'r');
   end
   return maps
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
   local ipatches = {}
   local img_maxw = {}
   local img_minw = {}
   local img_maxwumpt = {}
   local img_minwompt = {}
   local wrapped_images = {}

   -- loops through the images and creates an index size of the panorama
   -- with only the indexes to that image.
   for i = 1,self.nimages do 
      ipatches[i] = torch.Tensor(2,self.panosize[2],self.panosize[1])
      if torch.typename(maps[i]) ~= 'torch.PipeFile' then 
         maps[i]:seek(1)
      end
      local ixy = ipatches[i]
      if not img_maxw[i] then img_maxw[i] = -math.huge end
      if not img_minw[i] then img_minw[i] =  math.huge end
      if not img_maxwumpt[i] then img_maxwumpt[i] = -math.huge end
      if not img_minwompt[i] then img_minwompt[i] =  math.huge end
      for x = 1,self.imgwidth[i] do 
         for y = 1,self.imgheight[i] do
            local px = math.floor(maps[i]:readFloat() + 0.55)
            local py = math.floor(maps[i]:readFloat() + 0.55)
            if (((px > self.panocrop[1]) and (px <= self.panocrop[2])) 
             and 
             ((py > self.panocrop[3]) and (py <= self.panocrop[4]))) then
               if px > self.panomidpt then 
                  -- over midpoint 
                  if px < img_minwompt[i] then img_minwompt[i] = px end
               else
                  if px > img_maxwumpt[i] then img_maxwumpt[i] = px end
               end
               if px > img_maxw[i] then img_maxw[i] = px end
               if px < img_minw[i] then img_minw[i] = px end
               local ipy = py-self.panocrop[3]
               local ipx = px-self.panocrop[1]
               -- fill index
               ixy[1][ipy][ipx] = y
               ixy[2][ipy][ipx] = x
            end
         end
      end
   end
   -- more tricky to determine wrapped images (can have multiple)
   for i = 1,self.nimages do
      if img_minw[i] == 1 then
         img_maxw[i] = img_maxwumpt[i]
         img_minw[i] = img_minwompt[i]
         wrapped_images[i] = true
      else
         wrapped_images[i] = false
      end
      print(i,img_minw[i],img_maxw[i],wrapped_images[i])
   end
   -- find boundaries.  Given the stored max and min index for each
   -- image.  compute overlaps and copy index to final panorama
   -- loops through all the image maps and find the overlaps.  Picks 1/2
   -- way point of overlap to switch input images in the output.  Assumes
   -- horizonal sequential images, so not very general
   for i = 1,self.nimages do
      local prev = i-1
      local next = i+1
      local crop_left   = 0
      local crop_right   = 0
      local crop_width = 0
      local overlap_left  = 0
      local overlap_right = 0
      if prev < 1 then prev = self.nimages end
      if next > self.nimages then next = 1 end
      if (not wrapped_images[i]) then
         if crop_left ~= 0 then 
            crop_left = crop_right
         else
            overlap_max = (img_maxw[i] - img_minw[next]) / 2
            crop_right  =  img_maxw[i] - overlap_max
         end
         overlap_min = (img_maxw[prev] - img_minw[i]) / 2
         crop_left   =  img_minw[i] + overlap_min
         crop_width  =  crop_right  - crop_left
         self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
         self.index:narrow(1,2,2):narrow(3,crop_left,crop_width):copy(ipatches[i]:narrow(3,crop_left,crop_width))
      else
         -- copy two bits (right part)
         if (not wrapped_images[prev]) then
            overlap_min = (img_maxw[prev] - img_minw[i]) / 2
            crop_left   =  img_minw[i] + overlap_min
            crop_right  =  self.panosize[1]
            crop_width  =  crop_right  - crop_left
            print(i,crop_left,crop_right,crop_width)
            self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
            self.index:narrow(1,2,2):narrow(3,crop_left,crop_width):copy(ipatches[i]:narrow(3,crop_left,crop_width)) 
         end
         -- left part
         if (not wrapped_images[next]) then
            overlap_max = (img_maxw[i] - img_minw[next]) / 2 
            crop_left   =  1
            crop_right  =  img_maxw[i] - overlap_max
            crop_width  =  crop_right  - crop_left
            print(i,crop_left,crop_right,crop_width)
            self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
            self.index:narrow(1,2,2):narrow(3,crop_left,crop_width):copy(ipatches[i]:narrow(3,crop_left,crop_width))
         end
      end
   end
end



function Stitcher:stitch (img, pano)
   local pano = pano or self.panorama
   pano:resizeAs(self.index)
   for i = 1,self.panosize[2] do 
      for j = 1,self.panosize[1] do
         local imgidx = self.index[1][i][j]
         local yidx   = self.index[2][i][j]
         local xidx   = self.index[3][i][j]
         if xidx > 0 and xidx <= self.imgwidth[i] and 
            yidx > 0 and yidx <= self.imgheight[i] then
            pano:select(3,j):select(2,i):copy(img[imgidx]:select(3,xidx):select(2,yidx))
         end
      end 
   end
end

-- need to pass table of images to C function.
function Stitcher:stitch_c (frames)
   -- pano.resize()
   libstitch.stitch(self.panorama,self.index,frames)
end