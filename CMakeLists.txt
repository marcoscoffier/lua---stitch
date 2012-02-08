CMAKE_MINIMUM_REQUIRED(VERSION 2.6 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.6)
FIND_PACKAGE(Torch REQUIRED)
SET(src stitch.c)
SET(luasrc init.lua)
ADD_TORCH_PACKAGE(stitch "${src}" "${luasrc}" "Interface to hugin .pto files for stitching")
TARGET_LINK_LIBRARIES(stitch luaT TH)

