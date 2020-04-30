local COMPONENT, COMPUTER, LOAD, TABLE, MATH, UNICODE, BACKGROUND, FOREGROUND, white = component, computer, load, table, math, unicode, 0x002b36, 0x8cb9c5, 0xffffff
local bootFiles, componentList, mathCeil, computerPullSignal, computerUptime, unicodeLen, proxy, execute, status, split, address, centerY, width, height = {
    "OS.lua",
    "init.lua"
}, COMPONENT.list, MATH.ceil, COMPUTER.pullSignal, COMPUTER.uptime, UNICODE.len

proxy, execute, split =

function(componentType)
    address = componentList(componentType)()
    return address and COMPONENT.proxy(address)
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

local gpu, internet, eeprom, screen = proxy"gp", proxy"te", proxy"pr", componentList"re"()
local gpuSetBackground, gpuSetForeground, eepromSetData, eepromGetData = gpu.setBackground, gpu.setForeground, eeprom.setData, eeprom.getData

COMPUTER.setBootAddress = eepromSetData
COMPUTER.getBootAddress = eepromGetData

if gpu and screen then
    gpu.bind((screen))
    width, height = gpu.maxResolution()
    centerY = height / 2
    gpu.setPaletteColor(9, BACKGROUND)
end

set, fill, clear, centrize, centrizedSet, status = 

function(x, y, string, background, foreground)
    gpuSetBackground(background or BACKGROUND)
    gpuSetForeground(foreground or FOREGROUND)
    gpu.set(x, y, string)
end,

function(x, y, w, h, symbol, background, foreground)
    gpuSetBackground(background or BACKGROUND)
    gpuSetForeground(foreground or FOREGROUND)
    gpu.fill(x, y, w, h, symbol)
end,

function()
    fill(1, 1, width, height, " ")
end,

function(len)
    return mathCeil(width / 2 - len / 2)
end,

function(y, text, background, foreground)
    set(centrize(unicodeLen(text)), y, text, background, foreground)
end,

function(text, title, wait, breakCode, onBreak)
    if gpu then
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

            if signal[1] == "key_down" and signal[4] == breakCode then
                if onBreak then
                    onBreak()
                end

                break
            elseif computerUptime() >= deadline then
                break
            end
        end
    end
end