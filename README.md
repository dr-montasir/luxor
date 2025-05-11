<div align="center">
  <br>
  <a href="https://github.com/dr-montasir/luxor">
      <img src="logo.svg" width="100">
  </a>
  <br>

  <h1>LUXOR</h1>

  <p>Luxor Project</p>
</div>


## Installation

```sh
luarocks install luxor
```

## Usage

```lua
-- app.lua
-- Require the luxor framework module
local luxor = require("luxor")

-- Installation via LuaRocks
-- Luxor can be easily installed using LuaRocks, the Lua package manager.
-- Run in your terminal:
-- luarocks install luxor

-- Verification
-- To verify that LuaSocket is installed correctly, open Lua and run:
--    local luxor = require("luxor")
--    print(luxor._INFO)
-- If you see output like "Luxor: A Simple Lua Web Framework\nV0.1.0-1", the installation was successful.

print(luxor._INFO)

-- Configure the framework
luxor.set_host("0.0.0.0") -- Listen on all available interfaces
luxor.set_port(8080)       -- Set the port to 8080

-- Set the static root for static files.
-- The framework will serve files from this directory when requests
-- start with "/" or "" or "./".
-- luxor.set_static_root("public")
-- luxor.set_static_root("public/assets")
-- luxor.set_static_root("assets")
luxor.set_static_root("src/assets")

-- Add a route for the root path ("/")
-- The handler function receives the request object and should return
-- the status code (string or number), status text (string), headers (as a table),
-- and the response body (string or nil).
-- Note on character encoding:
-- To ensure that the browser correctly interprets the character encoding of the HTML document,
-- you can either:
-- 1. Include a <meta> tag in the HTML head section:
--    This is done by adding <meta charset="utf-8"> within the <head> section of the HTML.
--    This method is useful for specifying the character set directly in the HTML content.
-- 
-- 2. Specify the charset in the response headers:
--    You can return the charset as part of the "Content-Type" header in the response.
--    For example: return "200", "OK", {["Content-Type"] = "text/html; charset=utf-8"}, dynamic_html
--    This method is preferred for ensuring that the server communicates the correct encoding
--    to the client before the HTML is processed.
-- 
-- In the current implementation, the charset is not specified in the headers:
-- return "200", "OK", {["Content-Type"] = "text/html"}, dynamic_html
-- To improve this, consider uncommenting the line with the charset included in the headers.
luxor.add_route("GET", "/", function(request)
    local sin30deg = math.sin(30 * math.pi / 180);
    local dynamic_html = [[
<!DOCTYPE html>
<html>
    <head>
        <title>My Dynamic Website</title>
        <link rel="stylesheet" href="/style.css">
    </head>
    <body>
        <h1>Hello from a dynamic index page! 👋</h1>
        <p>Request Method: ]] .. request.method .. [[</p>
        <p>Request Path: ]] .. request.path .. [[</p>
        <p><b>Sin(30 deg) = ]] .. sin30deg .. [[</b></p>
        <img src="/logo.svg" alt="/Logo">
        <img src="logo.svg" alt="Logo">
        <img src="./logo.svg" alt="./Logo">
        <br>
        <img src="/original.jpg" width="25%" alt="jpg image">
        <script src="/script.js"></script>
    </body>
</html>]]

    -- Return the response data (status_code, status_text, headers, body)
    -- return "200", "OK", {["Content-Type"] = "text/html"}, dynamic_html
    return "200", "OK", {["Content-Type"] = "text/html; charset=utf-8"}, dynamic_html
end)

luxor.add_route("GET", "/api/hello", function(request)
    local json_response = '{"message": "Hello, API!"}'
    return "200", "OK", {["Content-Type"] = "application/json"}, json_response
end)

local submit_handler = function(request)
    print("Received POST body:", request.body)
    return "200", "OK", {["Content-Type"] = "text/plain"}, "Data received!"
end

luxor.add_route("POST", "/submit", submit_handler)

-- You can add more routes here for other paths and methods:

-- Start the server
luxor.start()
```

- **Project structure**

```terminal
.
├── app.lua
├── assets
│   ├── logo.svg
│   ├── original.jpg
│   ├── script.js
│   └── style.css
├── public
│   ├── logo.svg
│   ├── original.jpg
│   ├── script.js
│   └── style.css
└── src
    └── assets
        ├── logo.svg
        ├── original.jpg
        ├── script.js
        └── style.css
```

- **style.css**

```css
body {
  background-color: lightgreen;
}
```

- **script.js**

```js
console.log("Hello from script.js!");

// window.alert("Hello from script.js!");
```

- **svg**

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="60" height="40" viewBox="0 0 60 40">
  <style>
    .title {
      font-family: Arial, sans-serif;
      font-size: 14px;
      font-weight: bold;
      fill: #ffffff;
    }

    .shadow {
      fill: rgba(0, 0, 185, 0.5);
      filter: drop-shadow(1px 1px 2px rgba(0, 0, 0, 0.2));
    }

    .curve {
      fill: none;
      stroke: #ffffff;
      stroke-width: 1.7;
    }

    .bg {
      fill: #00007c;
      stroke: #ffffff;
      stroke-width: 1;
      rx: 2;
    }
  </style>
  <rect class="bg" x="0" y="0" width="60" height="40" rx="5" />
  <!-- Text Shadow -->
  <text x="5" y="24" class="shadow">LUXOR</text>
  <!-- Main Text -->
  <text x="3" y="23" class="title">LUXOR</text>
  <path class="curve" d="M 55,20 Q 45,10 55,20 T 40,30" />
</svg>
```

---

## License

This project is licensed under either of the following licenses:

- MIT License
- Apache License, Version 2.0

You may choose either license for your purposes.
