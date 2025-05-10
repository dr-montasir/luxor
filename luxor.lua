-- Luxor a simple Lua Web Framework (Improved Socket and Parsing)

-- Installation via LuaRocks
-- Luxor can be easily installed using LuaRocks, the Lua package manager.
-- Run in your terminal:
-- luarocks install luxor

-- Verification
-- To verify that LuaSocket is installed correctly, open Lua and run:
--    local luxor = require("luxor")
--    print(luxor._INFO)
-- If you see output like "Luxor: A Simple Lua Web Framework\nV0.0.1-1", the installation was successful.

local luxor = require("lib.core") -- Load the core Luxor module

---------------------------------
-- LUXOR INFO FUNCTIONS
---------------------------------

local version = "0.0.1-1"

luxor._INFO = "Luxor: A Simple Lua Web Framework\nV" .. version

-- print(luxor._INFO)

---------------------------------
-- END LUXOR INFO FUNCTIONS
---------------------------------

return luxor -- Return the main luxor module at the end