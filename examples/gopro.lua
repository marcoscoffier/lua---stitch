require 'stitch'

index_file = 'examples/frame_300_index.tch'

s = stitcher.new()

-- imapf = {}
-- imapf[1] = torch.DiskFile('images/image0topano.map')
-- imapf[2] = torch.DiskFile('images/image1topano.map')
-- imapf[3] = torch.DiskFile('images/image2topano.map')
-- imapf[4] = torch.DiskFile('images/image3topano.map')
-- s:make_index(imapf)
-- s:save_index(index_file)

s:load_index(index_file)

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