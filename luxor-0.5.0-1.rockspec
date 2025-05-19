package = "luxor"
version = "0.5.0-1"
source = {
   url = "git+https://github.com/dr-montasir/luxor.git"
}
description = {
   summary = "A Lua Web Framework Designed for Simplicity and Ease of Use",
   detailed = "A Lua Web Framework Designed for Simplicity and Ease of Use",
   homepage = "https://github.com/dr-montasir/luxor",
   license = "MIT OR Apache-2.0",
   maintainer = "Montasir Mirghani"
}
dependencies = {
   "lua >= 5.1",
   "luasocket >= 2.0"
}
build = {
   type = "builtin",
   modules = {
    luxor = 'luxor.lua',
    ["lib.core"] = 'lib/core.lua',
    ["lib.client"] = 'lib/client.lua'
   }
}