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
  for(i=0;i<nimages;i++){
    images[i] = (THDoubleTensor *)luaT_checkudata(L, i+4, luaT_checktypename2id(L, "torch.DoubleTensor"));
    printf("image[%d] size = (%d,%d,%d)\n",i,
           image[i]->size[0],image[i]->size[1],image[i]->size[2]);
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
