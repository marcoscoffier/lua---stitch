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
  THTensor *offset_map =
    (THTensor *)luaT_checkudata(L, 2, torch_(Tensor_id));
  THTensor *images[MAXIMAGES];
  int i = 0;
  long npixels = offset_map->size[1]*offset_map->size[2];
  real *pano_pt   = THTensor_(data)(pano); 
  real *offset_pt = THTensor_(data)(offset_map);
  real *images_pt[MAXIMAGES];

  real * panoR = pano_pt;
  real * panoG = pano_pt +    pano->stride[0];
  real * panoB = pano_pt + (2*pano->stride[0]);
  THTensor * curImg = NULL;
  real * curImg_pt = NULL;
  long unsigned int XYoffset = 0;
  real imgR   = 0;
  real imgG   = 0; 
  real imgB   = 0;
  real * offImg = offset_pt;
  real * offX   = offset_pt +    offset_map->stride[0];
  real * offY   = offset_pt + (2*offset_map->stride[0]);
  int nimages = 0;
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
      images_pt[i] = THTensor_(data)(images[i]);
    }
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
