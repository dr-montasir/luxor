-- Framework Name (luxor) Request:
local luxor = {}

-- Configuration
luxor.config = {
    host = "localhost", -- Default host
    port = 8080,        -- Default port
    static_root = nil -- Optional static root for static files
}

-- Functions to set the host, port, and static root
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

-- Helper function to split a string (could be more robust, but okay for now)
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

-- Basic function to send a response
local function send_response(socket, status_code, status_text, headers, body)
    -- Ensure status_code and status_text are strings for concatenation
    local response = "HTTP/1.1 " .. tostring(status_code) .. " " .. tostring(status_text) .. "\r\n"

    -- Default headers
    response = response .. "Content-Length: " .. (body and #body or 0) .. "\r\n"
    response = response .. "Connection: close\r\n" -- Keep it simple for now

    -- Add custom headers
    if headers then
        for key, value in pairs(headers) do
            response = response .. tostring(key) .. ": " .. tostring(value) .. "\r\n"
        end
    end

    response = response .. "\r\n" -- End of headers

    -- Send headers
    -- Use pcall to catch errors during send, as socket might be closed
    local ok, err = pcall(socket.send, socket, response)
    if not ok then
        print("Error sending headers: " .. tostring(err))
        -- Attempt to close socket gracefully if pcall failed before it
        if socket and socket.close then
           pcall(socket.close, socket) -- Use pcall again just in case
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
        pcall(socket.close, socket) -- Use pcall just in case
    end
end

-- Function to parse the incoming HTTP request (More Robust)
local function parse_request(socket)
    local request_data = ""
    local request_line = nil
    local headers = {}
    local body_content = nil
    local content_length = 0

    -- Set a timeout for receiving data
    -- Note: In a coroutine environment with non-blocking sockets,
    -- receive will yield instead of timing out if no data is available.
    -- The timeout here is more for if the client is truly idle for too long.
    socket:settimeout(5) -- 5 second timeout for inactivity

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


-- Function to add a route
function luxor.add_route(method, path, handler)
    method = string.upper(method)
    luxor.routes[method] = luxor.routes[method] or {}
    luxor.routes[method][path] = handler
end

-- Function to serve static files from disk
-- This is more memory efficient than loading all into memory at startup
local function serve_static_file(socket, requested_path)
    local file_path = luxor.config.static_root

    if not file_path then
        -- Static root not set, cannot serve static files
        send_response(socket, "500", "Internal Server Error", nil, "Static file serving not configured (document_root not set).")
        return
    end

    -- Basic path sanitization to prevent directory traversal
    -- This is NOT a complete security solution, but better than nothing.
    if requested_path:find("%.%.") or requested_path:find("~") or requested_path:find("\0") then
         send_response(socket, "403", "Forbidden", nil, "Invalid path.")
         return
    end

    -- Construct the full file path
    -- Ensure we handle leading/trailing slashes correctly
    local full_path = file_path .. "/" .. requested_path:gsub("^/", "") -- Remove leading slash from requested_path

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

    -- Get file size for Content-Length header
    local size_ok, size = pcall(file_info.seek, file_info, "end") -- Seek to end
    if not size_ok or not size then
         print("Error getting file size for " .. full_path .. ": " .. tostring(size))
         file_info:close()
         send_response(socket, "500", "Internal Server Error", nil, "Error reading file size.")
         return
    end
    file_info:seek("set", 0)         -- Seek back to beginning

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


    -- Send the file content in chunks (CORRECTED LOGIC)
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


-- Adding the function to handle requests (CORRECTED LOGIC)
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
             -- print("Client closed connection during request parsing.") -- Optional logging
             -- No response can be sent if the socket is already closed
        else -- Generic parsing error
            send_response(socket, "400", "Bad Request", nil, "Error Parsing Request")
        end
        -- parse_request already handles closing the socket on error, but let's be explicit
        -- Use pcall as socket might already be closed
        if socket and socket.close then pcall(socket.close, socket) end
        return
    end

    -- Log the parsed request line
    -- print(string.format("Request: %s %s %s", request.method, request.path, request.http_version))

    -- print("Headers:", request.headers) -- Uncomment to see parsed headers

    -- if request.body then print("Body:", request.body) end -- Uncomment to see body

    -- Check if the requested path is for a route handler
    if luxor.routes[request.method] and luxor.routes[request.method][request.path] then
        local handler = luxor.routes[request.method][request.path]

        -- Call the handler function, passing the request object
        -- Handlers should ideally return status_code, status_text, headers, body
        -- pcall returns true/false on success/failure followed by the function's return values or error message
        local ok, handler_status_code, handler_status_text, handler_headers, handler_body = pcall(handler, request)

        if not ok then -- pcall returned false, meaning the handler function errored
             -- The second return value (handler_status_code in this case) contains the error message
             print("Error in route handler for " .. request.method .. " " .. request.path .. ": " .. tostring(handler_status_code))
             send_response(socket, "500", "Internal Server Error", nil, "<h1>Internal Server Error</h1>Error in handler.")
        else -- Handler executed successfully, ok is true. The subsequent variables hold the returned values.
             -- Pass the returned values from the handler to send_response
             send_response(socket, handler_status_code, handler_status_text, handler_headers, handler_body)
        end

    -- Check if it's a GET request and potentially a static file
    -- We'll assume requests starting with /public/ are static files
    -- elseif request.method == "GET" and luxor.config.static_root and (request.path == "/public/" or request.path:find("^/public/")) then
    elseif request.method == "GET" and luxor.config.static_root and (request.path == "/" or request.path:find("^/")) then
        -- Extract the path relative to the static root
        -- local relative_path = request.path:gsub("^/public/", "")
        local relative_path = request.path:gsub("^/", "")
        if relative_path == "" then relative_path = "index.html" end -- Serve index.html for /public/

        serve_static_file(socket, relative_path)

    else
        -- No route found and not a GET request for static file (or static_root not set)
        send_response(socket, "404", "Not Found", nil, "<h1>404 Not Found</h1>")
    end
end

-- Function to start the server
function luxor.start()
    local socket_lib = require("socket")
    local server = socket_lib.tcp()

    -- Set socket options if needed (e.g., SO_REUSEADDR)
    server:setoption("reuseaddr", true)

    local bind_success, bind_err = server:bind(luxor.config.host, luxor.config.port)
    if not bind_success then
        print("Error binding to " .. luxor.config.host .. ":" .. luxor.config.port .. ": " .. tostring(bind_err))
        return false -- Indicate failure
    end

    local listen_success, listen_err = server:listen(10) -- Increased backlog
    if not listen_success then
        print("Error listening: " .. tostring(listen_err))
        server:close()
        return false -- Indicate failure
    end


    print("Server listening on " .. luxor.config.host .. ":" .. luxor.config.port)
    -- if luxor.config.static_root then
    --     print("Serving static files from: " .. luxor.config.static_root)
    -- end
    print("Press Ctrl+C to stop.")

    -- Use non-blocking sockets and coroutines for concurrent handling
    server:settimeout(0) -- Make the server socket non-blocking

    -- Simple coroutine scheduler (very basic)
    local living_coroutines = {}

    local function spawn_handler(client_socket)
        local co = coroutine.create(function()
            -- Use pcall around the handler call within the coroutine
            -- handle_request itself has internal pcalls, but this outer one
            -- catches errors that might prevent handle_request from even starting correctly.
            local ok, err = pcall(handle_request, client_socket)
            if not ok then
                print("Unhandled error in handler coroutine (before/during handle_request start): " .. tostring(err))
                 -- If an error occurred before send_response could close the socket
                 if client_socket and client_socket.close then
                     pcall(client_socket.close, client_socket) -- Attempt to close
                 end
            end

            -- Remove self from the list when done (or errored)
            -- We need to find the current coroutine
            local current_co = coroutine.running()
            for i = #living_coroutines, 1, -1 do -- Iterate backwards for safe removal
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
        -- Accept new connections non-blocking
        local client_socket, err = server:accept()

        if client_socket then
            -- New connection, spawn a coroutine to handle it
            local handler_co = spawn_handler(client_socket)
            local status, msg = coroutine.resume(handler_co)
             if status == false then
                -- Error during the *initial* resume (e.g., syntax error in handler function or setup)
                print("Error during initial resume of handler coroutine: " .. tostring(msg))
                -- The coroutine is dead, spawn_handler will remove it.
                -- Close the socket immediately as no handler was successfully started.
                if client_socket and client_socket.close then pcall(client_socket.close, client_socket) end
             end

        elseif err ~= "timeout" then
            -- Real error accepting connection
            print("Error accepting connection: " .. tostring(err))
            -- In a real server, you might want to pause or exit here
            break -- Exit the loop on a real accept error
        end

        -- Resume living coroutines (those that yielded, e.g., waiting for socket data)
        -- This is a very simple poll loop. A real async loop would be more sophisticated.
        -- Iterate backwards because table.remove is used by the coroutine itself
        for i = #living_coroutines, 1, -1 do
            local co = living_coroutines[i]
            -- Check if the coroutine is suspended and not dead
            if coroutine.status(co) == "suspended" then
                local status, msg = coroutine.resume(co)
                 if status == false then
                    print("Error resuming handler coroutine: " .. tostring(msg))
                    -- Coroutine errored, it will be removed by spawn_handler in its cleanup
                 end
             elseif coroutine.status(co) == "dead" then
                -- Coroutine already finished or errored and removed itself.
                -- This check is mostly for safety; the coroutine itself should remove itself.
                -- We could add extra cleanup here if needed, but the current logic is fine.
            -- Coroutine is running or normal exit, nothing to do here.
            end
        end

        -- Prevent the loop from consuming 100% CPU in a tight loop with no connections
        -- Adjust the sleep time as needed. A more advanced loop would only wake when sockets are ready.
        socket_lib.sleep(0.001) -- Sleep for 1 millisecond (can adjust)
    end

    -- Clean up server socket on exit
    server:close()
    print("Server stopped.")
    -- Note: Living coroutines might still be running or suspended.
    -- A proper shutdown would involve signaling them to stop and waiting.
    return true -- Indicate successful shutdown (or exit)
end

return luxor