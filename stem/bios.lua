c = { -- Configuration
    a = "stem.fomalhaut.me", -- Stem address
    b = 5733, -- Stem port
    c = "rrct", -- Robot channel
    d = 1, -- Robot ID
    f = 20, -- How often to check for connection to the Stem
    g = 3, -- PIng timeout
}

local internet, send, subscribe, unsubscribe, ping, isConnected, reconnect, disconnect = component.proxy(component.list("inter")())

do local __pullSignal, __channels, __stream, __nextConnectionCheck, __build_package, __incoming, __process,  __socket = computer.pullSignal, {}, "", 0
    __build_package = function(type, id, message)
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

    send = function(id, message)
        if isConnected() then
            local data = __build_package(0, id, message)
            local sent = 0
            repeat
                local result, message = __socket.write(data:sub(sent + 1))
                if not result then return nil, message end
                sent = sent + result
            until sent == #data
            return true
        else
            return nil, "not connected"
        end
    end

    subscribe = function(id)
        if isConnected() then
            __socket.write(__build_package(1, id))
            __channels[id] = true
            return true
        else
            return nil, "not connected"
        end
    end

    unsubscribe = function(id)
        if isConnected() then
            __socket.write(__build_package(2, id))
            __channels[id] = false
            return true
        else
            return nil, "not connected"
        end
    end

    ping = function(content)
        -- send ping request
        __socket.write(__build_package(3, content))
        -- wait for response
        local time, duration = os.time(), c.g
        while true do
            local name, data = computer.pullSignal(duration)
            if name == "stem_pong" then
                return data == content
            else
                local passed = os.time() - time
                if passed >= duration * 20 then
                    return false
                else
                    duration = c.g - (passed / 20)
                end
            end
        end
    end

    isConnected = function()
        if __socket == nil then
            return nil, "there were no connection attempts"
        else
            return __socket.finishConnect()
        end
    end

    reconnect = function()
        if isConnected() then
            disconnect()
        end
        __socket = internet.connect(c.a, c.b)
        computer.pullSignal = function(...)
            local signal = {__pullSignal(...)}

            if signal[1] == "internet_ready" then
                __incoming(signal[3])
            end
            if computer.uptime() >= __nextConnectionCheck then
                __nextConnectionCheck = computer.uptime()
                if not ping(math.random()) then
                    reconnect()
                    for channel in pairs(__channels) do 
                        __channels[channel] = nil
                        subscribe(channel)
                    end
                end
            end
            return table.unpack(signal)
        end
        -- check connection until there will be some useful information
        -- also this serves to kick off internet_ready events generation
        while true do
            local result, error = __socket.finishConnect()
            if result then
                return 
            elseif result == nil then
                disconnect()
                return nil, error
            end
        end
    end

    disconnect = function()
        __socket.close()
        __channels, __stream, computer.pullSignal = {}, "", __pullSignal
    end

    __incoming = function(socket_id)
        -- check if the message belongs to the current connection
        if __socket.id() == socket_id then
            -- read all contents of the socket
            while true do
                local chunk = __socket.read()
                if chunk ~= nil and #chunk > 0 then
                    __stream = __stream .. chunk
                else
                    break
                end
            end
            -- read all packages that may be already downloaded
            while true do
                -- calculate the next package size, if necessary
                if len == nil and #__stream >= 2 then
                    local a, b = __stream:byte(1, 2)
                    len = a * 256 + b
                end
                -- check if the stream contains enough bytes for the package to be retrieved
                if len ~= nil and #__stream >= len + 2 then
                    -- determine the package type
                    local type = __stream:byte(3)
                    local package = { type = type }
                    if type == 3 or type == 4 then
                        -- read content
                        package.content = __stream:sub(4, len + 2)
                    else
                        -- read channel ID
                        local id_len = __stream:byte(4)
                        local id = __stream:sub(5, id_len + 4)
                        package.id = id
                        -- read a message
                        if type == 0 then
                            package.message = __stream:sub(id_len + 5, len + 2)
                        end
                    end
                    -- handle the package to processor
                    __process(package)
                    -- trim the stream
                    __stream = __stream:sub(len + 3)
                    len = nil
                else
                    break
                end
            end
        end
    end

    __process = function(package)
        if package.type == 0 then
            computer.pushSignal("stem_message", package.id, package.message)
        elseif package.type == 3 then
            __socket.write(__build_package(4, package.content))
        elseif package.type == 4 then
            computer.pushSignal("stem_pong", package.content)
        end
    end
end

reconnect()
subscribe("test")

while true do
    send("test", table.concat({computer.pullSignal(math.huge)}, "    "))
end