--https://gitlab.com/UnicornFreedom/stem
 
--local event = require("event")
--local computer = require("computer")
--local com = require("component")
--local internet = com.internet
 
local socket, channels, stream = nil, {}, ""
 
local function buildPackage(type, id, message)
    local package = string.char(type)
    if type == 3 or type == 4 then
        -- ping/pong content takes place of the `id` argument here
        package = package .. id
    else
        package = package .. string.char(#id) .. id
        if message ~= nil then
            package = package .. message
        end
    end
    local len = #package
    package = string.char(math.floor(len / 256), len % 256) .. package
    return package
end
 
function isSubscribed(id)
    return channels[id]
end
 
function send(id, message)
    if isConnected() then
        socket.write(buildPackage(0, id, message))
        return true
    else
        return nil, "not connected"
    end
end
 
function subscribe(id)
    if isConnected() then
        socket.write(buildPackage(1, id))
        channels[id] = true
        return true
    else
        return nil, "not connected"
    end
end
 
function unsubscribe(id)
    if isConnected() then
        socket.write(buildPackage(2, id))
        channels[id] = false
        return true
    else
        return nil, "not connected"
    end
end
 
function ping(content, timeout)
    -- send ping request
    socket.write(buildPackage(3, content))
    -- wait for response
    local time = os.time()
    local duration = timeout or 5
    while true do
        local name, data = computer.pullSignal(duration)
        if name == "stem_pong" then
            return data == content
        else
            local passed = os.time() - time
            if passed >= duration * 20 then
                return false
            else
                duration = (timeout or 5) - (passed / 20) --5 ping timeout
            end
        end
    end
end
 
function isConnected()
    if socket == nil then
        return nil, "there were no connection attempts"
    else
        return socket.finishConnect()
    end
end
 
function reconnect()
    if isConnected() then
        disconnect()
    end
    socket = internet.connect("stem.fomalhaut.me", 5733) --port
    -- check connection until there will be some useful information
    -- also this serves to kick off internet_ready events generation
    while true do
        local result, error = socket.finishConnect()
        if result then
            return true
        elseif result == nil then
            disconnect()
            return nil, error
        end
    end
end
 
function disconnect()
    socket.close()
    channels = {}
    stream = ""
end
 
local function process(package)
    if package.type == 0 then
        computer.pushSignal("stem_message", package.id, package.message)
    elseif package.type == 3 then
        socket.write(buildPackage(4, package.content))
    elseif package.type == 4 then
        computer.pushSignal("stem_pong", package.content)
    end
end
 
local function incoming(socket_id)
    -- check if the message belongs to the current connection
    if socket.id() == socket_id then
        -- read all contents of the socket
        while true do
            local chunk = socket.read()
            if chunk ~= nil and #chunk > 0 then
                stream = stream .. chunk
            else
                break
            end
        end
        -- read all packages that may be already downloaded
        while true do
            local len = nil
            -- calculate the next package size, if necessary
            if len == nil and #stream >= 2 then
                local a, b = stream:byte(1, 2)
                len = a * 256 + b
            end
            -- check if the stream contains enough bytes for the package to be retrieved
            if len ~= nil and #stream >= len + 2 then
                -- determine the package type
                local type = stream:byte(3)
                local package = { type = type }
                if type == 3 or type == 4 then
                    -- read content
                    package.content = stream:sub(4, len + 2)
                else
                    -- read channel ID
                    local id_len = stream:byte(4)
                    local id = stream:sub(5, id_len + 4)
                    package.id = id
                    -- read a message
                    if type == 0 then
                        package.message = stream:sub(id_len + 5, len + 2)
                    end
                end
                -- handle the package to processor
                process(package)
                -- trim the stream
                stream = stream:sub(len + 3)
                len = nil
            else
                break
            end
        end
    end
end
 
function connect()
    pullSignal = computer.pullSignal
    computer.pullSignal = function(...)
        local signal = {pullSignal(...)}
        if signal[1] == "internet_ready" then
            incoming(signal[3])
        end
 
        return table.unpack(signal)
    end
    reconnect()
end
