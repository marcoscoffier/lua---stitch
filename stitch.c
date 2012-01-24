#include <luaT.h>
#include <TH/TH.h>

#include <stdio.h>

#define MAXIMAGES 256
// Stitch takes args.
// pano - a torch tensor in RGB with dims (3 x height x width)
//
// offset_map - a torch tensor same h and w as pano storing offsets and 
// and image indices.  The two feaure dimentions are:
//  -- image number (starting at 1) and
//  -- bit offset in image tensor
// nimages - is the number of images use to make the panorama
// image1, ... imagen - are the image in a torch tensor
static int stitch_l(lua_State *L) {
  THDoubleTensor *pano = (THDoubleTensor *)luaT_checkudata(L, 1, luaT_checktypename2id(L, "torch.DoubleTensor"));
  THDoubleTensor *offset_map = (THDoubleTensor *)luaT_checkudata(L, 2, luaT_checktypename2id(L, "torch.DoubleTensor"));
  int nimages = lua_tonumber(L,3);
  THDoubleTensor *images[MAXIMAGES];
  int i = 0;
  long npixels = offset_map->size[1]*offset_map->size[2];
  double *pano_pt   = THDoubleTensor_data(pano); 
  double *offset_pt = THDoubleTensor_data(offset_map);
  double *images_pt[MAXIMAGES];

  double * panoR = pano_pt;
  double * panoG = pano_pt +    pano->stride[0];
  double * panoB = pano_pt + (2*pano->stride[0]);
  THDoubleTensor * curImg = NULL;
  double * curImg_pt = NULL;
  long unsigned int XYoffset = 0;
  double imgR   = 0;
  double imgG   = 0; 
  double imgB   = 0;
  double * offImg = offset_pt;
  double * offX   = offset_pt +    offset_map->stride[0];
  double * offY   = offset_pt + (2*offset_map->stride[0]);
  /* finish processing input image tensors */
  for(i=0;i<nimages;i++){
    images[i] = (THDoubleTensor *)luaT_checkudata(L, i+4, luaT_checktypename2id(L, "torch.DoubleTensor"));
    images_pt[i]    = THDoubleTensor_data(images[i]);
  }

  for(i=0;i<npixels;i++){
    curImg    = images[(long unsigned int)*offImg - 1];
    curImg_pt = images_pt[(long unsigned int)*offImg - 1]; 
    if ((*offX > 0) && (*offX < curImg->size[1]) &&
        (*offY > 0) && (*offY < curImg->size[2])){
      XYoffset  = 
        ((long unsigned int)*offX * curImg->stride[1] +
         (long unsigned int)*offY);
      imgR   = curImg_pt[XYoffset];
      imgG   = curImg_pt[XYoffset + curImg->stride[0]] ;
      imgB   = curImg_pt[XYoffset + (2 * curImg->stride[0])];
      *panoR = imgR;
      *panoG = imgG;
      *panoB = imgB;
    }
    panoR++;
    panoG++;
    panoB++;
    offImg++;
    offX++;
    offY++;
  }
}

// Register functions in LUA
static const struct luaL_reg stitch_funcs [] = {
  {"stitch", stitch_l},
  {NULL, NULL}  /* sentinel */
};

int luaopen_libstitch (lua_State *L) {
  luaL_openlib(L, "libstitch", stitch_funcs, 0);
  return 1;
}
