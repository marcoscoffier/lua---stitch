require 'torch'
require 'image'

nimages = 4
iwidth=1280
iheight=960
psize = { 2588, 892 }
pcrop = { 0 , 2588, 245 , 731 }
pwidth = pcrop[2]-pcrop[1]
pmidpt = pwidth/2
pimgwidth = pwidth / nimages
pimgoverlap = 100
pheight = pcrop[4]-pcrop[3]

patches = {}
patches[1] = torch.Tensor(3,pheight,pwidth)
patches[2] = torch.Tensor(3,pheight,pwidth)
patches[3] = torch.Tensor(3,pheight,pwidth)
patches[4] = torch.Tensor(3,pheight,pwidth)

ipatches = {}
ipatches[1] = torch.Tensor(2,pheight,pwidth)
ipatches[2] = torch.Tensor(2,pheight,pwidth)
ipatches[3] = torch.Tensor(2,pheight,pwidth)
ipatches[4] = torch.Tensor(2,pheight,pwidth)

output = torch.Tensor(3,pheight,pwidth)
ioutput = torch.Tensor(3,pheight,pwidth)
imgioutput = torch.Tensor(3,pheight,pwidth)

imapf = {}
imapf[1] = torch.DiskFile('images/image0topano.map')
imapf[2] = torch.DiskFile('images/image1topano.map')
imapf[3] = torch.DiskFile('images/image2topano.map')
imapf[4] = torch.DiskFile('images/image3topano.map')

img = {}
img[1] = image.load('images/frame_00300_0.png')
img[2] = image.load('images/frame_00300_1.png')
img[3] = image.load('images/frame_00300_2.png')
img[4] = image.load('images/frame_00300_3.png')

img_maxw = {}
img_minw = {}
wrapped_image = false
wrapped_image_no = 0

sys.tic()
-- loops through the images and creates an index size of the panorama
-- with only the indexes to that image.
for i = 1,nimages do 
   imapf[i]:seek(1)
   local ixy = ipatches[i]
   if not img_maxw[i] then img_maxw[i] = -math.huge end
   if not img_minw[i] then img_minw[i] =  math.huge end
   for x = 1,iwidth do 
      for y = 1,iheight do
         local px = math.floor(imapf[i]:readFloat() + 0.5)
         local py = math.floor(imapf[i]:readFloat() + 0.5)
         if (((px > pcrop[1]) and (px <= pcrop[2])) and 
          ((py > pcrop[3]) and (py <= pcrop[4]))) then
            if wrapped_image then
               -- reverse max and min
               if px > pmidpt then 
                  -- over midpoint 
                  if px < img_minw[i] then img_minw[i] = px end
               else
                  if px > img_maxw[i] then img_maxw[i] = px end
               end
            else
               if px > img_maxw[i] then img_maxw[i] = px end
               if img_maxw[i] >= pcrop[2]-1 then 
                  wrapped_image = true 
                  img_maxw[i] = -math.huge
               end
               if px < img_minw[i] then img_minw[i] = px end
               if img_minw[i] <= pcrop[1]+1 then 
                  wrapped_image = true 
                  img_minw[i] = math.huge
               end
            end
            local ipy = py-pcrop[3]
            local ipx = px-pcrop[1]
            -- fill index
            ixy[1][ipy][ipx] = y
            ixy[2][ipy][ipx] = x
            -- copy RGB into patches for debugging
            patches[i]:select(3,ipx):select(2,ipy):copy(img[i]:select(3,x):select(2,y))
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
   output:copy(patches[wrapped_image_no])
   ioutput:select(1,1):fill(wrapped_image_no)
   ioutput:narrow(1,2,2):copy(ipatches[wrapped_image_no])
end

-- find boundaries.  Given the stored max and min index for each
-- image.  compute overlaps and copy index to final panorama
for i = 1,nimages do
   if wrapped_image_no > 1 and not (i == wrapped_image_no) then
      local prev = i-1
      local next = i+1
      local crop_min   = 0
      local crop_max   = 0
      local crop_width = 0
      local overlap_left  = 0
      local overlap_right = 0
      if prev < 1 then prev = nimages end
      if next > nimages then next = 1 end
      overlap_min = (img_maxw[prev] - img_minw[i]) / 2
      overlap_max = (img_maxw[i] - img_minw[next]) / 2
      crop_left   =  img_minw[i] + overlap_min
      crop_right  =  img_maxw[i] - overlap_max
      crop_width  =  crop_right  - crop_left 
      output:narrow(3,crop_left,crop_width):copy(patches[i]:narrow(3,crop_left,crop_width))
      ioutput:select(1,1):fill(i)
      ioutput:narrow(1,2,2):narrow(3,crop_left,crop_width):copy(ipatches[i]:narrow(3,crop_left,crop_width))
   end
end
print("copy patches to output"..sys.toc())
image.display(output)

sys.tic()
-- given images and index into panorama copy RGB values from images to
-- the panorama
for i = 1,pheight do 
   for j = 1,pwidth do
      local imgidx = ioutput[1][i][j]
      local yidx   = ioutput[2][i][j]
      local xidx   = ioutput[3][i][j]
      if xidx > 0 and xidx <= iwidth and 
         yidx > 0 and yidx <= iheight then
         imgioutput:select(3,j):select(2,i):copy(img[imgidx]:select(3,xidx):select(2,yidx))
      end
   end 
end
print("Just remapping: "..sys.toc())

