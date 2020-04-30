local COMPONENT, COMPUTER, LOAD, TABLE, MATH, UNICODE, BACKGROUND, FOREGROUND, white = component, computer, load, table, math, unicode, 0x002b36, 0x8cb9c5, 0xffffff
local bootFiles, bootCandidates, componentList, componentProxy, mathCeil, computerPullSignal, computerUptime, computerShutdown, unicodeLen, address, gpuAndScreen, centerY, width, height, proxy, execute, split, set, fill, clear, centrize, centrizedSet, status, ERROR, candidatesUpdate, bootPreview, boot = {
    "OS.lua",
    "init.lua"
}, {}, COMPONENT.list, COMPONENT.proxy, MATH.ceil, COMPUTER.pullSignal, COMPUTER.uptime, COMPUTER.shutdown, UNICODE.len

proxy, execute, split =

function(componentType)
    address = componentList(componentType)()
    return address and componentProxy(address)
end,

function(code, stdin, env)
    local chunk, err, data = LOAD("return " .. code, stdin, False, env)

    if not chunk then
        chunk, err = LOAD(code, stdin, False, env)
    end

    if chunk then
        data = TABLE.pack(xpcall(chunk, debug.traceback))

        if data[1] then
            TABLE.remove(data, 1)
            data.n = data.n - 1
            return 1, data
        else
            return False, data[2]
        end
    else
        return False, err
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
local gpuSetBackground, gpuSetForeground, gpuSetPaletteColor, eepromSetData, eepromGetData = gpu.setBackground, gpu.setForeground, gpu.setPaletteColor, eeprom.setData, eeprom.getData

COMPUTER.setBootAddress = eepromSetData
COMPUTER.getBootAddress = eepromGetData

if gpu and screen then
    gpuAndScreen, width, height = gpu.bind((screen)), gpu.maxResolution()
    centerY = height / 2
    gpuSetPaletteColor(9, BACKGROUND)
end

set, fill, clear, centrize, centrizedSet, status, ERROR, candidatesUpdate, bootPreview, boot =

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

function(text, title, wait, breakCode, onBreak) -- status()
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

            if signal[1] == "key_down" and signal[4] == breakCode or breakCode == 0 then
                if onBreak then
                    onBreak()
                end

                break
            elseif computerUptime() >= deadline then
                break
            end
        end
    end
end,

function(err) -- ERROR()
    if gpuAndScreen then
        status(err, "¯\\_(ツ)_/¯", MATH.huge, 0, computerShutdown)
    else
        error(err)
    end
end, 

function() -- candidatesUpdate()
    for filesystem in pairs(componentList("le")) do
    end
end, 

function() -- bootPreview()
end,

function(image) -- boot()
end

for i = 1, #bootCandidates do 
    boot(bootCandidates[i])
    computerShutdown()
end
ERROR("No bootable medium found!")