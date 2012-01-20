
package = "stitch"
version = "1.0-1"

source = {
   url = "stitch-1.0-1.tgz"
}

description = {
   summary = "Provides ability to use hugin/libpano stiching files to stitch images in torch7",
   detailed = [[  ]],
   homepage = "",
   license = "MIT/X11" -- or whatever you like
}

dependencies = {
   "lua >= 5.1",
   "torch",
   "xlua"
}

build = {
   type = "cmake",
   variables = {
      CMAKE_INSTALL_PREFIX = "$(PREFIX)"
   }
}
