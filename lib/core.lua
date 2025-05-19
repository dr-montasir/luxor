-- Luxor framework
local luxor = {}

-- Configuration
luxor.config = {
    host = "localhost", -- Default host
    port = 8080,        -- Default port
    static_root = nil -- Optional static root for static files
}

-- Functions to set the host, port, static root
function luxor.set_host(host)
    luxor.config.host = host
end

function luxor.set_port(port)
    luxor.config.port = port
end

function luxor.set_static_root(path)
    luxor.config.static_root = path
end

----------Future enhancements----------
----------------set root---------------
---------------------------------------

-- Future enhancements for flexibility:

-- I plan to add other root directories 
-- (such as uploads, private, etc.)
-- with similar setter functions:

-- function luxor.set_upload_root(path)
--     luxor.config.upload_root = path
-- end

-- function luxor.set_private_root(path)
--     luxor.config.private_root = path
-- end

---------/Future enhancements/---------
---------------/set root/--------------
---------------------------------------

-- Routes (URL patterns to handler functions)
luxor.routes = {}

-- Helper function to split a string
local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- Function to add route with pattern support
function luxor.add_route(method, pattern, handler)
    method = string.upper(method)
    -- Initialize route list for method if needed
    luxor.routes[method] = luxor.routes[method] or {}
    -- Store pattern and handler
    table.insert(luxor.routes[method], {pattern=pattern, handler=handler})
end

-- Function to match route pattern with path and extract parameters
local function match_route(pattern, path)
    local pattern_segments = {}
    for segment in string.gmatch(pattern, "[^/]+") do
        table.insert(pattern_segments, segment)
    end

    local path_segments = {}
    for segment in string.gmatch(path, "[^/]+") do
        table.insert(path_segments, segment)
    end

    -- Quick check: pattern segments should be less or equal to path segments
    if #pattern_segments ~= #path_segments then
        return false, nil
    end

    local params = {}

    for i = 1, #pattern_segments do
        local p_seg = pattern_segments[i]
        local path_seg = path_segments[i]

        if p_seg:sub(1, 1) == ":" then
            -- this is a parameter
            local param_name = p_seg:sub(2)
            params[param_name] = path_seg
        else
            -- fixed segment, must match exactly
            if p_seg ~= path_seg then
                return false, nil
            end
        end
    end

    return true, params
end

-- Function to find matching route and extract params
local function find_route(method, path)
    if not luxor.routes[method] then return nil, nil end
    for _, route in ipairs(luxor.routes[method]) do
        local matched, params = match_route(route.pattern, path)
        if matched then
            return route.handler, params
        end
    end
    return nil, nil
end

-- Basic function to send a response
local function send_response(socket, status_code, status_text, headers, body)
     -- Ensure status_code and status_text are strings for concatenation
    local response = "HTTP/1.1 " .. tostring(status_code) .. " " .. tostring(status_text) .. "\r\n"
    
    -- Default headers
    response = response .. "Content-Length: " .. (body and #body or 0) .. "\r\n"
    response = response .. "Connection: close\r\n"
    
    -- Add custom headers
    if headers then
        for key, value in pairs(headers) do
            response = response .. tostring(key) .. ": " .. tostring(value) .. "\r\n"
        end
    end

    response = response .. "\r\n" --End of headers

    
    -- Send headers
    -- Use pcall to catch errors during send, as socket might be closed
    local ok, err = pcall(socket.send, socket, response)
    if not ok then
        print("Error sending headers: " .. tostring(err))
        -- Attempt to close socket gracefully if pcall failed before it
        if socket and socket.close then
            pcall(socket.close, socket) 
        end
        return
    end

    -- Send body if exists
    if body then
        local ok_body, err_body = pcall(socket.send, socket, body)
        if not ok_body then
            print("Error sending body: " .. tostring(err_body))
            -- Attempt to close socket gracefully
            if socket and socket.close then 
                pcall(socket.close, socket) 
            end
            return
        end
    end

    -- Close the socket after sending the response (simple model)
    if socket and socket.close then 
        pcall(socket.close, socket) 
    end
end

-- Function to parse the incoming HTTP request
local function parse_request(socket)
    -- Set a timeout for receiving data
    -- Note: In a coroutine environment with non-blocking sockets,
    -- receive will yield instead of timing out if no data is available.
    -- The timeout here is more for if the client is truly idle for too long.
    socket:settimeout(5) -- 5 second timeout for inactivity
    local request_line
    local headers = {}
    local body_content
    local content_length = 0

    -- Read line by line until we get the request line and headers
    while true do
        local line, err = socket:receive("*l") -- Read until newline

        if err == "timeout" then
            print("Request receive timeout")
            return nil, "timeout"
        elseif err == "closed" then
            print("Socket closed during receive")
            return nil, "closed"
        elseif err then
            print("Error receiving request line/headers: " .. tostring(err))
            return nil, err
        end

        if not line or line == "" then -- End of headers (empty line)
            break
        end

        if not request_line then
            request_line = line
        else
             -- Parse header line
            local key, value = line:match("([^:]+):%s*(.+)")
            if key and value then
                headers[key:lower()] = value -- Store headers in lowercase
            end
        end
    end

    if not request_line then
        -- Received end of headers without a request line (shouldn't happen with valid requests)
        print("Received empty request or socket closed prematurely")
        return nil, "empty_request"
    end

    -- Parse request line
    local method, path, http_version = request_line:match("([^ ]+) ([^ ]+) (.+)")
    if not method or not path or not http_version then
        print("Malformed request line: " .. request_line)
        return nil, "malformed_request_line"
    end

    -- Check for Content-Length header to read the body
    local cl_header = headers["content-length"]
    if cl_header then
        content_length = tonumber(cl_header)
        if content_length and content_length > 0 then
             -- Read the request body
            local body, err = socket:receive(content_length) -- Read exactly Content-Length bytes
            if err == "timeout" then
                print("Request body receive timeout")
                return nil, "timeout"
            elseif err == "closed" then
                print("Socket closed during body receive")
                return nil, "closed"
            elseif err then
                print("Error receiving request body: " .. tostring(err))
                return nil, err
            end
            if body and #body == content_length then
                body_content = body
            else
                print("Did not receive expected body length or socket closed")
                return nil, "incomplete_body"
            end
        end
    end

    -- Reset timeout to default or a longer value if keeping connection open
    socket:settimeout(nil) -- Reset to blocking (or a longer keep-alive timeout)

    return {
        method = method:upper(), -- Normalize method
        path = path,
        http_version = http_version,
        headers = headers,
        body = body_content,
        -- Query parameters would be parsed from 'path' here if needed
    }, nil -- Return request object and no error
end

-- Function to serve static files from disk
local function serve_static_file(socket, requested_path)
    local file_path = luxor.config.static_root

    if not file_path then
        -- Static root not set, cannot serve static files
        send_response(socket, "500", "Internal Server Error", nil, "Static file serving not configured (document_root not set).")
        return
    end

    -- Basic path sanitization to prevent directory traversal
    if requested_path:find("%.%.") or requested_path:find("~") or requested_path:find("\0") then
         send_response(socket, "403", "Forbidden", nil, "Invalid path.")
         return
    end

    -- Handle path separator differences between Linux and Windows
    local path_separator = "/"
    if package.config:sub(1,1) == "\\" then
        -- Running on Windows, use backslash
        path_separator = "\\"
    end

    -- Construct the full file path
    -- Remove leading slash if present
    local sanitized_path = requested_path:gsub("^/+", "")
    -- Replace any forward slashes with the system's path separator
    if path_separator == "\\" then
        sanitized_path = sanitized_path:gsub("/", "\\")
    end
    local full_path = file_path .. path_separator .. sanitized_path

    -- Check if the file exists and is a regular file
    -- Use pcall for io.open as it can fail (e.g., permission errors)
    local ok_open, file_info = pcall(io.open, full_path, "rb") -- Open in binary read mode

    if not ok_open or not file_info then
        -- File not found or error opening
        local err_msg = file_info -- If ok_open is false, file_info holds the error
        -- print("Static file not found or error: " .. full_path .. " (" .. tostring(err_msg) .. ")") -- Optional logging
        send_response(socket, "404", "Not Found", nil, "<h1>404 Not Found</h1>")
        return
    end

    -- Get file size for Content-Length header
    local size_ok, size = pcall(file_info.seek, file_info, "end") -- Seek to end
    if not size_ok or not size then
         print("Error getting file size for " .. full_path .. ": " .. tostring(size))
         file_info:close()
         send_response(socket, "500", "Internal Server Error", nil, "Error reading file size.")
         return
    end
    file_info:seek("set", 0)         -- Seek back to beginning

    -- Function to determine Content-Type based on file extension
    local function content_type(full_path)
        local default_type = "application/octet-stream"
        -- Extract the extension from the filename
        local ext = full_path:match("%.(%w+)$")
        if ext then
            -- Convert extension to lowercase for case-insensitive matching
            ext = ext:lower()
            -- Check if extension exists in the mime_types table
            local mime_type = mime_types["." .. ext]
            if mime_type then
                return mime_type
            end
        end
        -- Return default if no match found
        return default_type
    end

    -- Build and send headers
    local headers = {
        ["Content-Type"] = content_type,
        ["Content-Length"] = tostring(size)
    }
    local response_headers = "HTTP/1.1 200 OK\r\n"
    for k, v in pairs(headers) do
        response_headers = response_headers .. tostring(k) .. ": " .. tostring(v) .. "\r\n"
    end
    response_headers = response_headers .. "Connection: close\r\n\r\n" -- Close connection

    local sent_headers_ok, err_headers = pcall(socket.send, socket, response_headers)
     if not sent_headers_ok then
        print("Error sending static file headers: " .. tostring(err_headers))
        file_info:close()
        if socket and socket.close then pcall(socket.close, socket) end
        return
    end

    -- Send the file content in chunks
    local chunk_size = 4096 -- Or adjust based on performance
    while true do
        local chunk_ok, chunk = pcall(file_info.read, file_info, chunk_size)
        if not chunk_ok or not chunk or #chunk == 0 then break end -- End of file or read error

        -- Use pcall for socket.send
        -- pcall returns true/false on success/failure, followed by the function's results or error
        local success, bytes_sent_or_error = pcall(socket.send, socket, chunk) -- Use clearer variable names

        if not success then
            -- pcall returned false, bytes_sent_or_error holds the error message
            print("Error sending static file chunk: " .. tostring(bytes_sent_or_error))
            -- Error during send, likely socket closed by client or network issue
            break -- Abort sending the rest of the file
        else
            -- pcall returned true, bytes_sent_or_error holds the number of bytes sent by socket.send
            -- Check if the full chunk was sent
            if bytes_sent_or_error < #chunk then
                print("Warning: Only sent partial static file chunk (" .. bytes_sent_or_error .. " of " .. #chunk .. " bytes)")
                -- This is unlikely with TCP unless the socket closes mid-send
                break -- Abort on partial send
            end
        end
    end

    file_info:close()
    if socket and socket.close then
        pcall(socket.close, socket) -- Use pcall just in case
    end
end

-- The main request handler
local function handle_request(socket)
    local request, parse_err = parse_request(socket)
    
    if parse_err then
         -- Send an appropriate error response based on the parse error
        if parse_err == "timeout" then
            send_response(socket, "408", "Request Timeout", nil, "Request Timeout")
        elseif parse_err == "malformed_request_line" then
            send_response(socket, "400", "Bad Request", nil, "Malformed Request Line")
        elseif parse_err == "incomplete_body" then
            send_response(socket, "400", "Bad Request", nil, "Incomplete Request Body")
        elseif parse_err == "closed" then
            -- socket closed, no response
            -- print("Client closed connection during request parsing.") -- Optional logging
        else -- Generic parsing error
            send_response(socket, "400", "Bad Request", nil, "Error Parsing Request")
        end
        -- parse_request already handles closing the socket on error, but let's be explicit
        -- Use pcall as socket might already be closed
        if socket and socket.close then 
            pcall(socket.close, socket) 
        end
        return
    end

    -- Find route handler with pattern matching
    local handler, route_params = find_route(request.method, request.path)

    if handler then
        -- Call handler with request and route_params
        local ok, status_code, status_text, headers, body = pcall(handler, request, route_params)
        if not ok then
            print("Error in route handler: " .. tostring(status_code))
            send_response(socket, "500", "Internal Server Error", nil, "<h1>Internal Server Error</h1>")
        else
            send_response(socket, status_code, status_text, headers, body)
        end
    elseif request.method == "GET" and luxor.config.static_root then
        local relative_path = request.path:gsub("^/", "")
        if relative_path == "" then relative_path = "index.html" end
        serve_static_file(socket, relative_path)
    else
        send_response(socket, "404", "Not Found", nil, "<h1>404 Not Found</h1>")
    end
end

-- Function to start server
function luxor.start()
    local socket_lib = require("socket")
    local server = socket_lib.tcp()
    server:setoption("reuseaddr", true)
    local bind_success, bind_err = server:bind(luxor.config.host, luxor.config.port)
    if not bind_success then
        print("Error binding to " .. luxor.config.host .. ":" .. luxor.config.port .. ": " .. tostring(bind_err))
        return false
    end
    local listen_success, listen_err = server:listen(10)
    if not listen_success then
        print("Error listening: " .. tostring(listen_err))
        server:close()
        return false
    end
    print("Server listening on " .. luxor.config.host .. ":" .. luxor.config.port)
    print("Press Ctrl+C to stop.")
    -- Non-blocking server socket
    server:settimeout(0)
    local socket_lib = require("socket")
    local living_coroutines = {}

    local function spawn_handler(client_socket)
        local co = coroutine.create(function()
            local ok, err = pcall(handle_request, client_socket)
            if not ok then
                print("Unhandled error in handler coroutine: " .. tostring(err))
                if client_socket and client_socket.close then pcall(client_socket.close, client_socket) end
            end
            -- Remove self from list
            local current_co = coroutine.running()
            for i = #living_coroutines, 1, -1 do
                if living_coroutines[i] == current_co then
                    table.remove(living_coroutines, i)
                    break
                end
            end
        end)
        table.insert(living_coroutines, co)
        return co
    end

    while true do
        local client_socket, err = server:accept()
        if client_socket then
            local co = spawn_handler(client_socket)
            local status, msg = coroutine.resume(co)
            if not status then
                print("Error during handler coroutine: " .. tostring(msg))
                if client_socket and client_socket.close then pcall(client_socket.close, client_socket) end
            end
        elseif err ~= "timeout" then
            print("Error accepting connection: " .. tostring(err))
            break
        end

        for i = #living_coroutines, 1, -1 do
            local co = living_coroutines[i]
            if coroutine.status(co) == "suspended" then
                local status, msg = coroutine.resume(co)
                if not status then
                    print("Error resuming handler coroutine: " .. tostring(msg))
                end
            end
        end

        -- Prevent the loop from consuming 100% CPU in a tight loop with no connections
        -- Adjust the sleep time as needed. A more advanced loop would only wake when sockets are ready.
        socket_lib.sleep(0.001) -- Sleep for 1 millisecond
    end

     -- Clean up server socket on exit
    server:close()
    print("Server stopped.")
    -- Note: Living coroutines might still be running or suspended.
    -- A proper shutdown would involve signaling them to stop and waiting.
    return true -- Indicate successful shutdown (or exit)
end

return luxor