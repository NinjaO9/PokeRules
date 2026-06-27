----------------------------------------------------------
-- mGBA Cross-Network Socket Sync (Server + Client)
-- Author: You
-- Purpose: Allow multiple mGBA instances to sync data
----------------------------------------------------------

-- ==== CONFIGURATION ====
local ROLE = "server"  -- "server" or "client"
local HOST = "127.0.0.1" -- server IP (ignored if ROLE == "server")
local PORT = 5566

-- ==== INTERNAL VARIABLES ====
local server = nil
local clients = {}
local connection = nil -- used for the client
local frameCount = 0

-- ==== LOGGING ====
local function log(msg)
    console:log(string.format("[%s] %s", ROLE, msg))
end
local function errorLog(msg)
    console:error(string.format("[%s] %s", ROLE, msg))
end

-- ==== BROADCAST (Server Only) ====
local function broadcast(msg)
    for _, c in pairs(clients) do
        c:send(msg)
    end
end

-- ==== SERVER SETUP ====
local function startServer()
    log("Starting server on port " .. PORT .. "...")
    server = socket.tcp()
    local result = server:bind("127.0.0.1", PORT)
    console:log("Bind result: " .. tostring(result))
    console:log("Error message: " .. tostring(socket.ERRORS[result]))
    if result ~= 0 then
        errorLog("Failed to bind port (already in use?)")
        return
    end

    server:listen(5)
    log("Server started successfully! Waiting for clients...")

    -- Frame callback: accept and poll connections
    callbacks:add("frame", function()
        -- Accept new clients
        local newClient = server:accept()
        if newClient then
            table.insert(clients, newClient)
            log("New client connected! Total clients: " .. #clients)

            -- When data is received from this client
            newClient:add("received", function()
                local msg = newClient:receive(1024)
                if msg then
                    log("Received from client: " .. msg)
                    broadcast("Broadcast: " .. msg)
                end
            end)
        end

        -- Poll all sockets each frame
        server:poll()
        for _, c in pairs(clients) do
            c:poll()
        end
    end)
end

-- ==== CLIENT SETUP ====
local function startClient()
    log("Connecting to " .. HOST .. ":" .. PORT .. " ...")
    local client, err = socket.connect(HOST, PORT)
    if not client then
        errorLog("Connection failed: " .. tostring(err))
        return
    end
    connection = client
    log("Connected to server!")

    -- Handle incoming messages
    connection:add("received", function()
        local msg = connection:receive(1024)
        if msg then
            log("Received from server: " .. msg)
        end
    end)

    -- Send periodic updates to the server
    callbacks:add("frame", function()
        frameCount = frameCount + 1
        if frameCount % 120 == 0 then
            local msg = "Client update @ frame " .. frameCount
            connection:send(msg)
            log("Sent: " .. msg)
        end
        connection:poll()
    end)
end

-- ==== STARTUP ====
if ROLE == "server" then
    startServer()
else
    startClient()
end

log("Script loaded and running as " .. ROLE .. ".")
