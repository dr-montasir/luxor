-- Luxor
-- A Lua Web Framework Designed for Simplicity and Ease of Use.

-- Installation via LuaRocks
-- Luxor can be easily installed using LuaRocks, the Lua package manager.
-- Run in your terminal:
-- luarocks install luxor

-- Verification
-- To verify that LuaSocket is installed correctly, open Lua and run:
--    local luxor = require("luxor")
--    print(luxor._INFO)
-- If you see output like "Luxor: A Lua Web Framework Designed for 
-- Simplicity and Ease of Use.\nVersion: 0.5.0-1", the installation was successful.

local luxor = require("lib.core") -- Load the core Luxor module

---------------------------------
-- LUXOR INFO FUNCTIONS
---------------------------------

local version = "Version: 0.5.0-1"

local dependencies = "  lua >= 5.1\n  luasocket >= 2.0"

luxor._INFO = "Luxor: A Lua Web Framework Designed for Simplicity and Ease of Use\n" .. version .. "\nDependencies:\n" ..dependencies.. "\n" ..string.rep(".", 32)

---------------------------------
-- END LUXOR INFO FUNCTIONS
---------------------------------

local client = require("lib.client") -- Load the client module

luxor.http_client = client

return luxor -- Return the main luxor module at the end