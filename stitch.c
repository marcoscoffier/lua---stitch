#include <TH.h>
#include <luaT.h>

#define torch_(NAME) TH_CONCAT_3(torch_, Real, NAME)
#define torch_string_(NAME) TH_CONCAT_STRING_3(torch., Real, NAME)
#define Lstitch_(NAME) TH_CONCAT_3(Lstitch_, Real, NAME)

static const void* torch_FloatTensor_id = NULL;
static const void* torch_DoubleTensor_id = NULL;

#include "generic/stitch.c"
#include "THGenerateFloatTypes.h"

DLL_EXPORT int luaopen_libstitch(lua_State *L)
{
  torch_FloatTensor_id = luaT_checktypename2id(L, "torch.FloatTensor");
  torch_DoubleTensor_id = luaT_checktypename2id(L, "torch.DoubleTensor");

  Lstitch_FloatInit(L);
  Lstitch_DoubleInit(L);

  return 1;
}
