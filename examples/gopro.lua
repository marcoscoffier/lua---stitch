require 'stitch'

index_file = 'examples/frame_300_index.tch'

s = stitcher.new()

if (sys.fstat(index_file)) then
   s:load_index(index_file)
else
   sys.tic()
   s:make_index(s:make_maps())
   s:save_index(index_file)
   print("made index in", sys.toc())
end

img = {}
img[1] = image.load('images/frame_00300_0.png')
img[2] = image.load('images/frame_00300_1.png')
img[3] = image.load('images/frame_00300_2.png')
img[4] = image.load('images/frame_00300_3.png')

sys.tic()
libstitch.stitch(s.panorama,s.index,s.nimages,img[1],img[2],img[3],img[4])
print('lua stitch',sys.toc())
image.display(s.panorama)
-- p = torch.Tensor()
-- sys.tic()
-- s:stitch(img,p)
-- print('stitch lua for loop',sys.toc())