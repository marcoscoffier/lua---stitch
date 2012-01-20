cmake_minimum_required(VERSION 2.8)

set (CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR})

IF(${CMAKE_PROJECT_NAME} STREQUAL "Torch")
  SET(TORCH_LIBRARIES TH luaT)
  SET(TORCH_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

  SET(INSTALL_PREFIX /${Torch_INSTALL_LUA_PATH_SUBDIR}/image)
  SET(CINSTALL_PREFIX /${Torch_INSTALL_LUA_CPATH_SUBDIR})
  INCLUDE_DIRECTORIES(${LUA_INCLUDE_DIR})
  SET(LIBS ${TORCH_LIBRARIES} ${LUA_LIBRARIES})
ELSE(${CMAKE_PROJECT_NAME} STREQUAL "Torch")
  # infer path for Torch7
  string (REGEX REPLACE "(.*)lib/luarocks/rocks.*" "\\1" TORCH_PREFIX "${CMAKE_INSTALL_PREFIX}" )
  message (STATUS "Found Torch7, installed in: " ${TORCH_PREFIX})
  
  find_package (Torch REQUIRED)
  SET(INSTALL_PREFIX /lua/stitch)
  SET(CINSTALL_PREFIX /lib)
ENDIF(${CMAKE_PROJECT_NAME} STREQUAL "Torch")

# SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

include_directories (${TORCH_INCLUDE_DIR} ${PROJECT_SOURCE_DIR})
add_library (stitch SHARED stitch.c)
link_directories (${TORCH_LIBRARY_DIR})
target_link_libraries (stitch ${TORCH_LIBRARIES})
install_targets(${CINSTALL_PREFIX} stitch)
install_files(${INSTALL_PREFIX} init.lua)
