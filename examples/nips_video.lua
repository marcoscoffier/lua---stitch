require 'stitch'
require 'image'

pto_file = 'examples/frame_00768.pto'
index_file = pto_file:gsub(".pto","_index.th")

s = stitcher.new(pto_file)

if (sys.fstat(index_file)) then
   s:load_index(index_file)
else
   sys.tic()
   s:make_index(s:make_maps())
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
s.panorama.stitch.stitch(s.panorama,s.index,s.nimages,
                         imgs[1],imgs[2],imgs[3],imgs[4],imgs[5])
print('lua stitch',sys.toc())
image.display(s.panorama)
