cmake_minimum_required(VERSION 2.8)

set (CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR})

# infer path for Torch7
string (REGEX REPLACE "(.*)lib/luarocks/rocks.*" "\\1" TORCH_PREFIX "${CMAKE_INSTALL_PREFIX}" )
message (STATUS "Found Torch7, installed in: " ${TORCH_PREFIX})

find_package (Torch REQUIRED)

SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

include_directories (${TORCH_INCLUDE_DIR})
add_library (stitch SHARED stitch.c)
link_directories (${TORCH_LIBRARY_DIR})
target_link_libraries (stitch ${TORCH_LIBRARIES})

install_files(/lua stitch.lua)
install_targets(/lib stitch)
