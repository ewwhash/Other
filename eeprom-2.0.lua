local COMPONENT, COMPUTER, MATH, UNICODE, BACKGROUND, FOREGROUND, white = component, computer, math, unicode, 0x002b36, 0x8cb9c5, 0xffffff
local bootFiles, bootCandidates, componentList, componentProxy, mathCeil, computerPullSignal, computerUptime, computerShutdown, unicodeLen, unicodeSub, mathHuge, keyDown, keyUp, address, gpuAndScreen, selectedElementsLine, centerY, width, height, proxy, execute, split, request, set, fill, clear, centrize, centrizedSet, status, ERROR, addCandidate, cutText, input, updateCandidates, bootPreview, boot, createElements = {
    "/OS.lua",
    "/init.lua"
}, {}, COMPONENT.list, COMPONENT.proxy, MATH.ceil, COMPUTER.pullSignal, COMPUTER.uptime, COMPUTER.shutdown, UNICODE.len, UNICODE.sub, MATH.huge, "key_down", "key_up"

proxy, execute, split =

function(componentType)
    address = componentList(componentType)()
    return address and componentProxy(address)
end,

function(code, stdin, env)
    local chunk, err = load(code, stdin, FALSE, env)

    if chunk then
        return xpcall(chunk, debug.traceback)
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

local gpu, eeprom, internet, screen = proxy"gp" or {}, proxy"pr", proxy"in", componentList"re"()
local gpuSet, gpuSetBackground, gpuSetForeground, gpuSetPaletteColor, eepromSetData, eepromGetData = gpu.set, gpu.setBackground, gpu.setForeground, gpu.setPaletteColor, eeprom.setData, eeprom.getData

COMPUTER.setBootAddress = eepromSetData
COMPUTER.getBootAddress = eepromGetData

if gpuSet and screen then
    gpuAndScreen, width, height = gpu.bind((screen)), gpu.maxResolution()
    centerY = height / 2
    gpuSetPaletteColor(9, BACKGROUND)
end

request, set, fill, clear, centrize, centrizedSet, status, ERROR, addCandidate, updateCandidates, cutText, input, bootPreview, boot, createElements =

function(url) -- request()
    if internet then
        local handle, data, chunk = internet.request(url), ""

        ::LOOP::
        chunk = handle.read()

        if chunk then
            data = data .. chunk
            goto LOOP
        end

        handle.close()

        return data
    else
        return status("This option requires internet card", FALSE, mathHuge, 0)
    end
end,

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
        gpuSetPaletteColor(9, BACKGROUND)
        local lines, deadline, y, signalType, code, _ = split(text), computerUptime() + (wait or 0)
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
            signalType, _, _, code = computerPullSignal(computerUptime() - deadline)

            if signalType == keyDown and (code == breakCode or breakCode == 0) then
                if onBreak then
                    onBreak()
                end

                break
            elseif computerUptime() >= deadline then
                if booting and gpuAndScreen then
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
    bootCandidates = {}
    addCandidate(eepromGetData())

    for filesystem in pairs(componentList("le")) do
        addCandidate(eepromGetData() ~= filesystem and filesystem or "")
    end
end,

function(text, maxLength) -- cutText()
    return unicodeLen(text) > maxLength and unicodeSub(text, 1, maxLength) .. "…" or text
end,

function(prefix, y) -- input()
    local text, prefixLen, cursorState, signalType, char, _ = "", unicodeLen(prefix), FALSE

    while 1 do
        signalType, _, char = computerPullSignal(.5)

        if signalType == keyDown then
            if char == 13 then
                break
            elseif char >= 32 then
                text = text .. UNICODE.char(char)
            elseif char == 8 then
                text = unicodeSub(text, 1, unicodeLen(text) - 1)
            end

            cursorState = 1
        elseif signalType == "clipboard" then
            text = text .. char
            cursorState = 1
        elseif signalType ~= keyUp then
            cursorState = not cursorState
        end

        fill(1, y, width, 1, " ")
        set(centrize(prefixLen + unicodeLen(text)), y, prefix .. text .. (cursorState and "█" or ""), BACKGROUND, white)
    end

    fill(1, y, width, 1, " ")
    return text
end,

function(image, booting) -- bootPreview()
    address = cutText(image[3], booting and 36 or 6)
    return image[4] and ("Boot%s %s from %s (%s)"):format(booting and "ing" or "", image[4], image[2], address) or ("Boot from %s (%s) is not available"):format(image[2], address)
end,

function(image) -- boot()
    if image[4] then
        if eepromGetData() ~= image[3] then
            eepromSetData(image[3])
        end
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

        if not success and err then
            ERROR(err)
        end

        return 1
    end
end,

function(elements, y, borderType, onArrowKeyUpOrDown, onElementSelected) -- createElements()
    -- borderType - 1 == small border
    -- borderType - 2 == big border

    return {
        e = elements,
        s = 1,
        k = onArrowKeyUpOrDown,
        d = function(SELF, withoutBorder, withoutSelect) -- draw()
            fill(1, y - 1, width, 3, " ", BACKGROUND)
            selectedElementsLine = withoutSelect and selectedElementsLine or SELF
            local elementsAndBorderLength, borderSpaces, elementLength, x, selectedElement, element = 0, borderType == 1 and 6 or 8

            if onElementSelected then
                onElementSelected(SELF)
            end

            for i = 1, #SELF.e do
                elementsAndBorderLength = elementsAndBorderLength + unicodeLen(SELF.e[i].t) + borderSpaces
            end

            elementsAndBorderLength = elementsAndBorderLength -  borderSpaces
            x = centrize(elementsAndBorderLength)

            for i = 1, #SELF.e do
                selectedElement, element = SELF.s == i and 1, SELF.e[i]
                elementLength = unicodeLen(element.t)

                if selectedElement and not withoutBorder then
                    fill(x - borderSpaces / 2, y - (borderType == 1 and 0 or 1), elementLength + borderSpaces, borderType == 1 and 1 or 3, " ", FOREGROUND)
                    set(x, y, element.t, FOREGROUND, BACKGROUND)
                else
                    set(x, y, element.t, BACKGROUND, FOREGROUND)
                end

                x = x + elementLength + borderSpaces
            end
        end
    }
end

status("Press ALT to stay in bootloader", FALSE, .5, 56, function()
    ::REFRESH::
    updateCandidates()
    local signalType, code, options, drives, draw, bootImage, proxy, readOnly, newLabel, cmdOrUrl, data, _

    options = createElements({
        {t = "Power off", a = function() computerShutdown() end}, -- Это сделано, потому что я вызываю функцию через :, туда вставляется self, и из-за этого компьютер перезагружается, а не выключается
        {t = "Execute", a = function()
            cmdOrUrl = input("Cmd or URL: ", centerY + 7)
            
            if cmdOrUrl:match("http[s]?://") then
                status("Downloading...")
                code = request(cmdOrUrl)
            else
                code = cmdOrUrl
            end

            _, data = execute(code, "=stdin")
            status((data == "" or not data and "is empty") or data, "Command result", mathHuge, 0)
            draw(FALSE, FALSE, 1, 1)
        end}
    }, centerY + 2, 1, function(keyState)
        if keyState == 0 then
            selectedElementsLine = drives
            draw(1, 1, FALSE, FALSE)
        end
    end)

    drives = createElements({}, centerY - 2, 2, function(keyState)
        if keyState == 1 then
            selectedElementsLine = options
            draw(FALSE, FALSE, 1, 1)
        end
    end, function(SELF)
        bootImage = bootCandidates[SELF.s]
        proxy = bootImage[1]
        readOnly = proxy.isReadOnly()

        fill(1, centerY + 5, width, 3, " ")
        centrizedSet(centerY + 5, bootPreview(bootImage), FALSE, white)
        centrizedSet(centerY + 7, ("Disk usage %s%% %s"):format(MATH.floor(proxy.spaceUsed() / (proxy.spaceTotal() / 100)), readOnly and "R/O" or"R/W"))

        if readOnly then
            if options.s > 2 then
                options.s = 2
            end
            options.e[3] = FALSE
            options.e[4] = FALSE
        else
            options.e[3] = {t = "Rename", a = function()
                newLabel = input("New label: ", centerY + 9)

                if newLabel and newLabel ~= "" then
                    pcall(proxy.setLabel, newLabel)
                    bootImage[2] = cutText(newLabel, 16)
                    drives.e[SELF.s].t = cutText(newLabel, 6)
                    drives:d(1, 1)
                    options:d()
                end
            end}
            options.e[4] = {t = "Format", a = function() proxy.remove("/") drives:d(1, 1) options:d() end}
        end

        options:d(1, 1)
    end)

    for i = 1, #bootCandidates do
        drives.e[i] = {t = cutText(bootCandidates[i][2], 6), a = function(SELF)
            boot(bootCandidates[SELF.s])
        end}
    end

    draw = function(optionsWithoutBorder, optionsWithoutSelect, drivesWithoutBorder, drivesWithoutSelect)
        clear()
        drives:d(drivesWithoutBorder, drivesWithoutSelect)
        options:d(optionsWithoutBorder, optionsWithoutSelect)
        centrizedSet(height, "Use ← ↑ → keys to move cursor; Enter to do something; F5 to refresh")
    end

    draw(1, 1)

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
                selectedElementsLine.e[selectedElementsLine.s].a(selectedElementsLine)
            elseif code == 63 then
                goto REFRESH
            end
        end
    goto LOOP
end)

updateCandidates()
for i = 1, #bootCandidates do
    if boot(bootCandidates[i]) then
        computerShutdown()
    end
end
ERROR("No bootable medium found!")