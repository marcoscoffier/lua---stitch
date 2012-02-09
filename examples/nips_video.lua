require 'stitch'
require 'image'

pto_file = 'examples/frame_00768.pto'
index_file = pto_file:gsub(".pto","_index.th")

s = stitcher.new(pto_file)

if (sys.fstat(index_file)) then
   s:load_index(index_file)
else
   sys.tic()
   s:make_reverse_index(s:make_reverse_maps())
   s:save_index(index_file)
   print("made index in", sys.toc())
end



imgs = {}
imgs[1] = image.load("examples/frame_1_00768.png")
imgs[2] = image.load("examples/frame_2_00768.png")
imgs[3] = image.load("examples/frame_3_00768.png")
imgs[4] = image.load("examples/frame_4_00768.png")
imgs[5] = image.load("examples/frame_5_00768.png")

sys.tic()
panorama = torch.Tensor()
s:stitch(panorama,imgs)
print('<stitching>',sys.toc())
image.display(panorama)
