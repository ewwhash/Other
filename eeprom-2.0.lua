local COMPONENT, COMPUTER, LOAD, TABLE, MATH, UNICODE, BACKGROUND, FOREGROUND, white = component, computer, load, table, math, unicode, 0x002b36, 0x8cb9c5, 0xffffff
local bootFiles, bootCandidates, componentList, componentProxy, mathCeil, computerPullSignal, computerUptime, computerShutdown, unicodeLen, mathHuge, address, gpuAndScreen, centerY, width, height, proxy, execute, split, set, fill, clear, centrize, centrizedSet, status, ERROR, addCandidate, cutText, updateCandidates, bootPreview, boot = {
    "/OS.lua",
    "/init.lua"
}, {}, COMPONENT.list, COMPONENT.proxy, MATH.ceil, COMPUTER.pullSignal, COMPUTER.uptime, COMPUTER.shutdown, UNICODE.len, MATH.huge

proxy, execute, split =

function(componentType)
    address = componentList(componentType)()
    return address and componentProxy(address)
end,

function(code, stdin, env)
    local chunk, err, data = LOAD("return " .. code, stdin, FALSE, env)

    if not chunk then
        chunk, err = LOAD(code, stdin, FALSE, env)
    end

    if chunk then
        data = TABLE.pack(xpcall(chunk, debug.traceback))

        if data[1] then
            TABLE.remove(data, 1)
            data.n = data.n - 1
            return 1, data
        else
            return FALSE, data[2]
        end
    else
        return FALSE, err
    end
end,

function(text, tabulate)
    local lines = {}

    for line in text:gmatch"[^\r\n]+" do
        lines[#lines + 1] = line:gsub("\t", tabulate and "    " or "")
    end

    return lines
end

local gpu, eeprom, screen = proxy"gp", proxy"pr", componentList"re"()
local gpuSet, gpuSetBackground, gpuSetForeground, gpuSetPaletteColor, eepromSetData, eepromGetData = gpu.set, gpu.setBackground, gpu.setForeground, gpu.setPaletteColor, eeprom.setData, eeprom.getData

COMPUTER.setBootAddress = eepromSetData
COMPUTER.getBootAddress = eepromGetData

if gpu and screen then
    gpuAndScreen, width, height = gpu.bind((screen)), gpu.maxResolution()
    centerY = height / 2
    gpuSetPaletteColor(9, BACKGROUND)
end

set, fill, clear, centrize, centrizedSet, status, ERROR, addCandidate, updateCandidates, cutText, bootPreview, boot =

function(x, y, string, background, foreground) -- set()
    gpuSetBackground(background or BACKGROUND)
    gpuSetForeground(foreground or FOREGROUND)
    gpu.set(x, y, string)
end,

function(x, y, w, h, symbol, background, foreground) -- fill()
    gpuSetBackground(background or BACKGROUND)
    gpuSetForeground(foreground or FOREGROUND)
    gpu.fill(x, y, w, h, symbol)
end,

function() -- clear()
    fill(1, 1, width, height, " ")
end,

function(len) -- centrize()
    return mathCeil(width / 2 - len / 2)
end,

function(y, text, background, foreground) -- centrizedSet()
    set(centrize(unicodeLen(text)), y, text, background, foreground)
end,

function(text, title, wait, breakCode, onBreak, booting) -- status()
    if gpuAndScreen then
        local lines, deadline, y, signal = split(text), COMPUTER.uptime() + (wait or 0)
        y = mathCeil(centerY - #lines / 2) + 1
        clear()

        if title then
            centrizedSet(y - 1, title, BACKGROUND, white)
            y = y + 1
        end

        for i = 1, #lines do
            centrizedSet(y, lines[i])
            y = y + 1
        end

        while wait do
            signal = {computerPullSignal(deadline - COMPUTER.uptime())}

            if signal[1] == "key_down" and (signal[4] == breakCode or breakCode == 0) then
                if onBreak then
                    onBreak()
                end

                break
            elseif computerUptime() >= deadline then
                if booting then
                    gpu.set = function(...)
                        gpuSetPaletteColor(9, 0x336699)
                        gpuSet(...)
                        gpu.set = gpuSet
                        computer.beep()
                    end
                end
                break
            end
        end
    end
end,

function(err) -- ERROR()
    return gpuAndScreen and status(err, "¯\\_(ツ)_/¯", mathHuge, 0, computerShutdown) or error(err)
end,

function(address) -- addCandidate()
    local proxy = componentProxy(address)

    if proxy then
        bootCandidates[#bootCandidates + 1] = {
            proxy, proxy.getLabel() or "N/A", address
        }

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                bootCandidates[#bootCandidates][4] = bootFiles[i]
            end
        end
    end
end,

function() -- updateCandidates()
    addCandidate(eepromGetData())
    for filesystem in pairs(componentList("le")) do
        addCandidate(filesystem)
    end
end,

function(text, maxLength) -- cutText()
    return unicodeLen(text) > maxLength and UNICODE.sub(text, 1, maxLength) .. "…" or text
end,

function(image, booting) -- bootPreview()
    address = cutText(image[3], booting and 36 or 6)
    return image[4] and ("Boot%s %s from %s (%s)"):format(booting and "ing" or "", image[4], image[2], address) or ("Boot from %s (%s) is not available"):format(image[2], address)
end,

function(image) -- boot()
    if image[4] then
        local handle, data, chunk, success, err = image[1].open(image[4], "r"), ""

        ::LOOP::
        chunk = image[1].read(handle, mathHuge)

        if chunk then
            data = data .. chunk
            goto LOOP
        end

        image[1].close(handle)
        status(bootPreview(image, 1), FALSE, .5, FALSE, FALSE, 1)
        success, err = execute(data, "=" .. image[4])
        gpuSetPaletteColor(9, BACKGROUND)

        if not success and err then
            ERROR(err)
        end

        return 1
    end
end

updateCandidates()
status("Press ALT to stay in bootloader", FALSE, .5, 56, function()
end)

for i = 1, #bootCandidates do
    if boot(bootCandidates[i]) then
        computerShutdown()
    end
end
ERROR("No bootable medium found!")