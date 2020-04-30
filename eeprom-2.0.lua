local COMPONENT, COMPUTER, LOAD, TABLE, MATH, background, foreground, address, centerY, width, height = component, computer, load, table, math, 0x002b36, 0x8cb9c5
local bootFiles, componentList = {
    "OS.lua",
    "init.lua"
}, COMPONENT.list

local proxy, execute = 

function(componentType)
    address = componentList(componentType)()
    return address and COMPONENT.proxy(componentType)
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
end

local gpu, internet, eeprom, screen = proxy"gp", proxy"te", proxy"pr", componentList"re"()
local gpuSet, gpuFill, gpuSetBackground, gpuSetForeground, eepromSetData, eepromGetData = gpu.setBackground, gpu.setForeground, eeprom.setData, eeprom.getData

COMPUTER.setBootAddress = eepromSetData
COMPUTER.getBootAddress = eepromGetData

if gpu and screen then
    gpu.bind((screen))
    width, height = gpu.getMaxResolution()
    centerY = height / 2
    gpu.setPaletteColor(9, background)
end