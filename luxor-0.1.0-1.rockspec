package = "luxor"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/dr-montasir/luxor.git"
}
description = {
   summary = "Luxor",
   detailed = "Luxor",
   homepage = "https://github.com/dr-montasir/luxor",
   license = "MIT OR Apache-2.0",
   maintainer = "Montasir Mirghani"
}
dependencies = {
   "lua >= 5.1, < 5.5",
   "luasocket >= 3.0"
}
build = {
   type = "builtin",
   modules = {
    luxor = 'luxor.lua',
    ["lib.core"] = 'lib/core.lua'
   }
}