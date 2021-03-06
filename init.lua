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
         table.insert(self.imgwidth, tonumber(w))
         table.insert(self.imgheight, tonumber(h))
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
   -- index is 2 numbers (index of image, offset to the xy for Red
   -- pixel location in image)
   self.index    = torch.LongTensor(2,self.panosize[2],self.panosize[1]) 
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
      local cmd = string.format("for y in `seq 1 %d` ; do for x in `seq 1 %d` ; do echo %d $x $y ; done ;done | pano_trafo %s",
                                 self.imgheight[i],self.imgwidth[i],
                                 i-1,self.pto_file)
      maps[i] = torch.PipeFile(cmd,'r');
   end
   return maps
end

-- wrapper to the command line hugin tool pano_trafo to make index
-- maps for all images in a .pto file
function Stitcher:make_reverse_maps()
   local maps = {}
   for i = 1,self.nimages do 
      local cmd = string.format("for y in `seq %d %d` ; do for x in `seq %d %d` ; do echo $x $y ; done ;done | pano_trafo -r %s %d",
                                self.panocrop[3],
                                self.panocrop[3]+self.panosize[2],
                                self.panocrop[1],
                                self.panocrop[1]+self.panosize[1],
                                self.pto_file,i-1)
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
function Stitcher:make_reverse_index(maps)
   local ipatches = {}
   local img_maxw = {}
   local img_minw = {}
   local img_maxwumpt = {}
   local img_minwompt = {}
   -- loops through the images and creates an index size of the panorama
   -- with only the indexes to that image.
   for i = 1,self.nimages do 
      if (self.nimages == 1) then 
         self.index:select(1,1):fill(1)
         ipatches[1] = self.index:select(1,2)
      else
         ipatches[i] = torch.Tensor(self.panosize[2],self.panosize[1])
      end
      if torch.typename(maps[i]) ~= 'torch.PipeFile' then 
         maps[i]:seek(1)
      end
      local ioff = ipatches[i]
      if not img_maxw[i] then img_maxw[i] = -math.huge end
      if not img_minw[i] then img_minw[i] =  math.huge end
      if not img_maxwumpt[i] then img_maxwumpt[i] = -math.huge end
      if not img_minwompt[i] then img_minwompt[i] =  math.huge end
      for py = 1,self.panosize[2] do
         for px = 1,self.panosize[1] do 
            local imgx = math.floor(maps[i]:readFloat() + 0.5)
            local imgy = math.floor(maps[i]:readFloat() + 0.5)
            -- check if point is valid
            if (((imgx > 0) and (imgx <= self.imgwidth[i])) 
             and 
             ((imgy > 0) and (imgy <= self.imgheight[i]))) then
               if px > self.panomidpt then 
                  -- over midpoint 
                  if px < img_minwompt[i] then img_minwompt[i] = px end
               else
                  if px > img_maxwumpt[i] then img_maxwumpt[i] = px end
               end
               if px > img_maxw[i] then img_maxw[i] = px end
               if px < img_minw[i] then img_minw[i] = px end
               ioff[py][px] = imgy * self.imgwidth[i] + imgx 
            end
         end
      end
   end
   if self.nimages > 1 then
      print(img_minw,img_maxw,img_minwompt,img_maxwumpt)
      self:find_boundaries(ipatches,img_minw,img_maxw,
                           img_minwompt,img_maxwumpt)
   end
end

-- from a bunch of maps (torch.Files) produced with make_maps(),
-- create a single index self.index
function Stitcher:make_index(maps)
   local ipatches = {}
   local img_maxw = {}
   local img_minw = {}
   local img_maxwumpt = {}
   local img_minwompt = {}
   -- loops through the images and creates an index size of the panorama
   -- with only the indexes to that image.
   for i = 1,self.nimages do 
      if (self.nimages == 1) then 
         self.index:select(1,1):fill(1)
         ipatches[1] = self.index:select(1,2)
      else
         ipatches[i] = torch.Tensor(self.panosize[2],self.panosize[1])
      end
      if torch.typename(maps[i]) ~= 'torch.PipeFile' then 
         maps[i]:seek(1)
      end
      local ioff = ipatches[i]
      if not img_maxw[i] then img_maxw[i] = -math.huge end
      if not img_minw[i] then img_minw[i] =  math.huge end
      if not img_maxwumpt[i] then img_maxwumpt[i] = -math.huge end
      if not img_minwompt[i] then img_minwompt[i] =  math.huge end
      for y = 1,self.imgheight[i] do
         for x = 1,self.imgwidth[i] do 
            local px = math.floor(maps[i]:readFloat() + 0.5)
            local py = math.floor(maps[i]:readFloat() + 0.5)
            if (((px > self.panocrop[1]) and (px <= self.panocrop[2])) 
             and 
             ((py > self.panocrop[3]) and (py <= self.panocrop[4]))) then
               -- keep track of min and max extent in the panorama of
               -- each image
               if px > self.panomidpt then 
                  -- over midpoint 
                  if px < img_minwompt[i] then img_minwompt[i] = px end
               else
                  -- under midpoint 
                  if px > img_maxwumpt[i] then img_maxwumpt[i] = px end
               end
               if px > img_maxw[i] then img_maxw[i] = px end
               if px < img_minw[i] then img_minw[i] = px end
               local ipy = py-self.panocrop[3]
               local ipx = px-self.panocrop[1]
               -- fill index
               ioff[ipy][ipx] = y * self.imgwidth[i] + x 
            end
         end
      end
   end
   if self.nimages > 1 then
      print(img_minw,img_maxw,img_minwompt,img_maxwumpt)
      self:find_boundaries(ipatches,img_minw,img_maxw,
                           img_minwompt,img_maxwumpt)
   end
end

function Stitcher:find_boundaries (ipatches,img_minw,img_maxw,
                                   img_minwompt,img_maxwumpt)
   local wrapped_images = {}
   -- more tricky to determine wrapped images (can have multiple)
   for i = 1,self.nimages do
      if img_minw[i] == 1 then
         img_maxw[i] = img_maxwumpt[i]
         img_minw[i] = img_minwompt[i]
         wrapped_images[i] = true
      else
         wrapped_images[i] = false
      end
   end
   -- find boundaries.  Given the stored max and min index for each
   -- image.  compute overlaps and copy index to final panorama
   -- loops through all the image maps and find the overlaps.
   -- Picks 1/2 way point of overlap to switch input images in the
   -- output.  Assumes horizonal sequential images, so not very
   -- general
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
            overlap_right = (img_maxw[i] - img_minw[next]) / 2
            crop_right  =  img_maxw[i] - overlap_right
         end
         overlap_left = (img_maxw[prev] - img_minw[i]) / 2
         crop_left   =  img_minw[i] + overlap_left
         crop_width  =  crop_right  - crop_left
         print(self.index:size())
         print(crop_left,crop_width)
         self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
         self.index:select(1,2):narrow(2,crop_left,crop_width):copy(ipatches[i]:narrow(2,crop_left,crop_width))
         
      else
         -- copy two bits (right part)
         if (not wrapped_images[prev]) then
            overlap_left = (img_maxw[prev] - img_minw[i]) / 2
            crop_left   =  img_minw[i] + overlap_left
            crop_right  =  self.panosize[1]
            crop_width  =  crop_right  - crop_left
            self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
            self.index:select(1,2):narrow(2,crop_left,crop_width):copy(ipatches[i]:narrow(2,crop_left,crop_width)) 
         end
         -- left part
         if (not wrapped_images[next]) then
            overlap_right = (img_maxw[i] - img_minw[next]) / 2 
            crop_left   =  1
            crop_right  =  img_maxw[i] - overlap_right
            crop_width  =  crop_right  - crop_left
            self.index:select(1,1):narrow(2,crop_left,crop_width):fill(i)
            self.index:select(1,2):narrow(2,crop_left,crop_width):copy(ipatches[i]:narrow(2,crop_left,crop_width))
         end
      end
   end
end
-- hack to get around the incorrect reverse mapping of multiple images
function Stitcher:fill_holes ()
   for y = 2,self.index:size(2) do 
      for x = 2,self.index:size(3) do
         if self.index[2][y][x] == 0 then
            if y % 2 == 0 then
               self.index:select(3,x):select(2,y):copy(self.index:select(3,x):select(2,y-1))
            else
               self.index:select(3,x):select(2,y):copy(self.index:select(3,x-1):select(2,y))
            end
         end
      end
   end
end


-- need to pass table of images to C function.
function Stitcher:stitch (panorama,frames)
   panorama:resize(3,self.panosize[2],self.panosize[1])
   panorama.stitch.stitch(panorama,self.index,frames)
end