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
  printf("pano size = (%ld,%ld,%ld)\n",
         pano->size[0],pano->size[1],pano->size[2]);
  printf("offset_map size = (%ld,%ld,%ld)\n",
         offset_map->size[0],offset_map->size[1],offset_map->size[2]);
  double *pano_pt = THDoubleTensor_data(pano); 
  double *offset_pt = THDoubleTensor_data(offset_map);
  double *images_pt[MAXIMAGES];
  long img_size[3];
  long img_stride[3];
  for(i=0;i<nimages;i++){
    images[i] = (THDoubleTensor *)luaT_checkudata(L, i+4, luaT_checktypename2id(L, "torch.DoubleTensor"));
    images_pt[i] = THDoubleTensor_data(images[i]);
    if (i == 0) {
      img_size[0] = images[i]->size[0];
      img_size[1] = images[i]->size[1];
      img_size[2] = images[i]->size[2];
      img_stride[0] = images[i]->stride[0];
      img_stride[1] = images[i]->stride[1];
      img_stride[2] = images[i]->stride[2];
    }
    printf("images[%d] size = (%ld,%ld,%ld)\n",i,
           images[i]->size[0],images[i]->size[1],images[i]->size[2]);
    printf("images[%d] stride = (%ld,%ld,%ld)\n",i,
           images[i]->stride[0],images[i]->stride[1],
           images[i]->stride[2]);
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
