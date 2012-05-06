#ifndef TH_GENERIC_FILE
#define TH_GENERIC_FILE "generic/stitch.c"
#else

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
static int Lstitch_(stitch)(lua_State *L) {
  int nargs = lua_gettop(L);
  THTensor *pano =
    (THTensor *)luaT_checkudata(L, 1, torch_(Tensor_id));
  THLongTensor *offset_map =
    (THLongTensor *)luaT_checkudata(L, 2, luaT_checktypename2id(L, "torch.LongTensor"));
  THTensor *images[MAXIMAGES];
  int i = 0;
  long npixels = offset_map->size[1]*offset_map->size[2];
  real *pano_pt   = THTensor_(data)(pano); 
  long *offset_pt = THLongTensor_data(offset_map);
  real *images_pt[MAXIMAGES];
  long images_npixels[MAXIMAGES];
  long images_Goff[MAXIMAGES];
  long images_Boff[MAXIMAGES];
  
  real * panoR = pano_pt;
  real * panoG = pano_pt +    pano->stride[0];
  real * panoB = pano_pt + (2*pano->stride[0]);
  real * curImg_pt  = NULL;
  long unsigned int XYoffset = 0;
  long * offImg      = offset_pt;
  long * offIndexXY  = offset_pt + offset_map->stride[0];
  int nimages = 0;
  long cImgOff = 0;
  /* finish processing input image tensors */
  /* either you can pass a table */
  /* or a number and variable length of args */
  if (nargs == 3){
    if (lua_istable(L,3)){
      nimages = lua_objlen (L, 3);
      /* table is in the stack at index 3 */
      lua_pushnil(L);  /* first key */
      i = 0;
      while (lua_next(L, 3) != 0) {
        /* 'key' (at index -2) and 'value' (at index -1) */
        images[i]    =
          (THTensor *)luaT_checkudata(L, -1, torch_(Tensor_id));
        images_npixels[i] = images[i]->size[1]*images[i]->size[2];
        images_Goff[i] = images[i]->stride[0];
        images_Boff[i] = 2*images[i]->stride[0];
        images_pt[i] = THTensor_(data)(images[i]);
        /* removes 'value'; keeps 'key' for next iteration */
        lua_pop(L, 1);
        i = i+1;
      }
    } else {
      lua_pushstring(L, "with 3 args last argument is a table");
      lua_error(L);
    }
  } else {
    nimages = lua_tonumber(L,3);
    for(i=0;i<nimages;i++){
      images[i]    =
        (THTensor *)luaT_checkudata(L, i+4, torch_(Tensor_id));
      images_npixels[i] = images[i]->size[1]*images[i]->size[2];
      images_Goff[i]    = images[i]->stride[0];
      images_Boff[i]    = 2*images[i]->stride[0];
      images_pt[i]      = THTensor_(data)(images[i]);
    }
  }
  for(i=0;i<npixels;i++){
    cImgOff   = (long unsigned int)*offImg - 1;
    curImg_pt = images_pt[cImgOff];
    if ((*offIndexXY > 0) &&
        (*offIndexXY < images_npixels[cImgOff])){
      XYoffset  =  (long unsigned int)*offIndexXY;
      *panoR   = curImg_pt[XYoffset];
      *panoG   = curImg_pt[XYoffset + images_Goff[cImgOff]] ; 
      *panoB   = curImg_pt[XYoffset + images_Boff[cImgOff]]; 
    }
    panoR++;
    panoG++;
    panoB++;
    offImg++;
    offIndexXY++;
  }
  return 0;
}

// Register functions in LUA
static const struct luaL_reg Lstitch_(Methods) [] = {
  {"stitch", Lstitch_(stitch)},
  {NULL, NULL}  /* sentinel */
};


void Lstitch_(Init)(lua_State *L)
{
  luaT_pushmetaclass(L, torch_(Tensor_id));
  luaT_registeratname(L, Lstitch_(Methods), "stitch");
}

#endif
