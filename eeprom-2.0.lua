local COMPONENT, COMPUTER, LOAD, TABLE, MATH, UNICODE, SELECT, BACKGROUND, FOREGROUND, white = component, computer, load, table, math, unicode, select, 0x002b36, 0x8cb9c5, 0xffffff
local bootFiles, bootCandidates, componentList, componentProxy, mathCeil, computerPullSignal, computerUptime, computerShutdown, unicodeLen, mathHuge, keyDown, address, gpuAndScreen, selectedElementsLine, centerY, width, height, proxy, execute, split, set, fill, clear, centrize, centrizedSet, status, ERROR, addCandidate, cutText, updateCandidates, bootPreview, boot, createElements, main = {
    "/OS.lua",
    "/init.lua"
}, {}, COMPONENT.list, COMPONENT.proxy, MATH.ceil, COMPUTER.pullSignal, COMPUTER.uptime, COMPUTER.shutdown, UNICODE.len, MATH.huge, "key_down"

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

set, fill, clear, centrize, centrizedSet, status, ERROR, addCandidate, updateCandidates, cutText, bootPreview, boot, createElements, main =

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
        local lines, deadline, y, signal = split(text), computerUptime() + (wait or 0)
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
            if SELECT(4, computerPullSignal(computerUptime() - deadline)) == breakCode or breakCode == 0 then
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
end,

function(elements, y, borderType, onArrowKeyUpOrDown) -- createElements()
    -- borderType - 1 == small border
    -- borderType - 2 == big border

    return {
        e = elements,
        s = 0,
        k = onArrowKeyUpOrDown,
        d = function(SELF) -- draw()
            fill(1, y - 1, width, 3, " ", BACKGROUND)
            selectedElementsLine = SELF
            local elementsAndBorderLength, borderSpaces, elementLength, x, selectedElement, element = 0, borderType == 1 and 6 or 8

            for i = 1, #SELF.e do
                elementsAndBorderLength = elementsAndBorderLength + unicodeLen(SELF.e[i].t) + borderSpaces
            end

            elementsAndBorderLength = elementsAndBorderLength -  borderSpaces

            x = centrize(elementsAndBorderLength)

            for i = 1, #SELF.e do
                selectedElement, element = SELF.s == i and 1, SELF.e[i]
                elementLength = unicodeLen(element.t)

                if selectedElement then
                    fill(x - borderSpaces / 2, y - (borderType == 1 and 0 or 1), elementLength + borderSpaces, borderType == 1 and 1 or 3, " ", FOREGROUND)
                    set(x, y, element.t, FOREGROUND, BACKGROUND)
                else
                    set(x, y, element.t, BACKGROUND, FOREGROUND)
                end

                x = x + elementLength + borderSpaces
            end
        end
    }
end,

function() -- main()
    clear()
    local signalType, code, options, drives, _

    options = createElements({
        {t = "OMSK"},
        {t = "BLOCKED"},
        {t = "AND"},
        {t = "DOESN'T EXISTS"}
    }, centerY + 2, 1, function(keyState)
        if keyState == 0 then
            selectedElementsLine = drives
            options.s = 0
            drives.s = mathCeil(#drives.e / 2)
            options:d()
            drives:d()
        end
    end)

    drives = createElements({}, centerY - 2, 2, function(keyState)
        if keyState == 1 then
            selectedElementsLine = options
            drives.s = 0
            options.s = mathCeil(#options.e / 2)
            error(#options.e)
            drives:d()
            options:d()
        end
    end)

    for i = 1, #bootCandidates do
        drives.e[i] = {t = bootCandidates[i][2]}
    end

    options:d()
    drives:d()

    ::LOOP::
        signalType, _, _, code = computerPullSignal()

        if signalType == keyDown then
            if code == 200 then -- Up
                selectedElementsLine.k(0)
            elseif code == 208 then -- Down
                selectedElementsLine.k(1)
            elseif code == 203 and selectedElementsLine.s > 1 then -- Left
                selectedElementsLine.s = selectedElementsLine.s - 1
                selectedElementsLine:d()
            elseif code == 205 and selectedElementsLine.s < #selectedElementsLine.e then -- Right
                selectedElementsLine.s = selectedElementsLine.s + 1
                selectedElementsLine:d()
            elseif code == 28 then -- Enter
                selectedElementsLine.e[selectedElementsLine.s].a()
            end 
        end
    goto LOOP
end

updateCandidates()
status("Press ALT to stay in bootloader", FALSE, .5, 56, main)

for i = 1, #bootCandidates do
    if boot(bootCandidates[i]) then
        computerShutdown()
    end
end
ERROR("No bootable medium found!")