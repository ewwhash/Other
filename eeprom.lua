local bootFiles, Component, Computer, Table, Math, Unicode, Pcall, Load, Select, Background, Foreground, white, spaces, keyDown, undefined, bootCandidates, False, gpuAndScreen, width, height, centerY, computerShutdown, selectedElement = {
    "/init.lua",
    "/OS.lua"
}, component, computer, table, math, unicode, pcall, load, select, 0x002b36, 0x8cb9c5, 0xffffff, "    ", "key_down", "undefined"

local componentProxy, componentList, computerPullSignal, computerUptime, mathHuge, mathCeil, tableInsert, tablePack, tableConcat, unicodeLen, unicodeSub = Component.proxy, Component.list, Computer.pullSignal, computer.uptime, Math.huge, Math.ceil, Table.insert, Table.pack, Table.concat, Unicode.len, Unicode.sub

local function proxy(componentType)
    local address = componentList(componentType)()
    return address and componentProxy(address)
end

local gpu, eeprom, internet, screen = proxy"gp" or {}, proxy"pr", proxy"in", proxy"sc"
local gpuSetBackground, gpuSetForeground, eepromGetData, eepromSetData = gpu.setBackground, gpu.setForeground, eeprom.getData, eeprom.setData
computer.getBootAddress = eepromGetData
computer.setBootAddress = eepromSetData
computerShutdown = function()
    Computer.shutdown()
end

if gpuSetBackground and screen then
    gpu.bind((componentList"sc"()))
    gpuAndScreen, width, height = 1, gpu.maxResolution()
    centerY = height / 2
    gpu.setPaletteColor(9, Background)
    gpu.setResolution(width, height)
end

local request, execute, read, ternary =

function(...)
    if internet then
        local handle, data, chunk = internet.request(...), ""

        ::loop::
            chunk = handle.read()

            if chunk then
                data = data .. chunk
            else
                handle.close()
                return data
            end
        goto loop
    end
end,

function(code, stdin, env)
    local chunk, err, data = Load("return " .. code, stdin, False, env)

    if not chunk then
        chunk, err = Load(code, stdin, False, env)
    end

	if not chunk and err then
		return False, err
	else
        data = tablePack(xpcall(chunk, debug.traceback))

        if data[1] then
            Table.remove(data, 1)
            data.n = data.n - 1
            return 1, data
        else
            return False, data[2]
        end
	end
end,

function(proxy, file)
    local handle, data, chunk = proxy.open(file, "r"), ""

    if handle then
        ::loop::
            chunk = proxy.read(handle, mathHuge)
            if chunk then
                data = data .. chunk
            else
                proxy.close(handle)
                return data
            end
        goto loop
    end
end,

function(condition, first, second)
    return condition and first or second
end

local set, fill, getCenterX, split =

function(x, y, text, background, foreground)
    gpuSetBackground(background or Background)
    gpuSetForeground(foreground or Foreground)
    gpu.set(x, y, text)
end,

function(x, y, width, height, symbol, background, foreground)
    gpuSetBackground(background or Background)
    gpuSetForeground(foreground or Foreground)
    gpu.fill(x, y, width, height, symbol)
end,

function(len)
    return mathCeil(width / 2 - len / 2)
end,

function(text, tabulate)
    local lines = {}

    for line in text:gmatch"[^\r\n]+" do
        lines[#lines + 1] = line:gsub("\t", ternary(tabulate, spaces, ""))
    end

    return lines
end

local clear, center, sleep, bootFrom, elementsLen, checkAction, cutLabel =

function()
    fill(1, 1, width, height, " ", Background)
end,

function(y, text, background, foreground)
    set(getCenterX(unicodeLen(text)), y, text, background, foreground)
end,

function(timeout, breakCode, onBreak)
    local deadline, signal = computerUptime() + (timeout or 0)
    
    repeat
        signal = {computerPullSignal(deadline - computerUptime())}

        if signal[1] == keyDown and (breakCode == 0 or signal[4] == breakCode) then
            if onBreak then
                onBreak()
            end
            return 1
        end
    until computerUptime() >= deadline
end,

function(bootImage, alreadyBooting)
    local address = ternary(alreadyBooting, bootImage[3], unicodeSub(bootImage[3], 1, 3) .. "…")
    
    if bootImage[4] then
        return ("Boot%s %s from %s (%s)"):format(ternary(alreadyBooting, "ing", ""), bootImage[5], bootImage[2], address)
    else
        return ("Boot from %s (%s) is not available"):format(bootImage[2], address)
    end
end,

function(elements, borderType)
    local allLen, len = 0

    for i = 1, #elements do
        len = unicodeLen(elements[i].t)
        allLen, elements[i].l = allLen + len + ternary(i == #elements, 0, ternary(borderType == 1, 6, 8)), len
    end

    return allLen
end,

function(action, Self)
    if action and type(action) == "function" then
        action(Self)
    end
end,

function(label)
    return ternary(not label, label, ternary(unicodeLen(label) > 8, unicodeSub(label, 1, 6) .. "…", label))
end

local status, input, print =

function(text, title, wait, breakCode, onBreak)
    if gpuAndScreen then
        local lines, y = split(text)
        y = mathCeil(centerY - #lines / 2) + 1
        clear()
        if title then
            center(y - 1, title, Background, white)
            y = y + 1
        end

        for i = 1, #lines do
            center(y, lines[i])
            y = y + 1
        end

        return sleep(wait, breakCode, onBreak)
    end
end,

function(y, centrize, prefix)
    local input, keys, cursorState, cursorPos, prefixLen, x, allLen, cursorX, text, signal, cursorBlink, draw = "", {}, 1, 1, unicodeLen(prefix or ""), 1

    cursorBlink = function(force)
        if allLen < width then
            cursorState, cursorX = force or not cursorState, x + prefixLen + cursorPos - 1
            set(cursorX, y, gpu.get(cursorX, y), ternary(cursorState, white, Background), ternary(cursorState, Background, white))
        end
    end

    draw = function()
        text = prefix .. input
        allLen = unicodeLen(text)
        fill(1, y, width, 1, " ")
        if centrize then
            x = getCenterX(allLen)
            cursorX = x + prefixLen
            set(x, y, text, Background, white)
        else
            set(1, y, text, Background, white)
        end
        cursorBlink(1)
    end

    draw()

    while 1 do
        signal = {computerPullSignal(.6)}

        if signal[1] == keyDown then
            keys[signal[4]] = 1
            if signal[3] >= 32 and unicodeLen(input) < width - prefixLen - 1 then
                input, cursorState, cursorPos = unicodeSub(input, 1, cursorPos - 1) .. Unicode.char(signal[3]) .. unicodeSub(input, cursorPos, -1), 1, cursorPos + 1
                draw()
            elseif signal[4] == 14 and #input > 0 then
                input, cursorState, cursorPos = unicodeSub(unicodeSub(input, 1, cursorPos - 1), 1, -2) .. unicodeSub(input, cursorPos, -1), 1, cursorPos - 1
                draw()
            elseif signal[4] == 28 then
                break
            elseif signal[4] == 203 and cursorPos > 1 then
                cursorPos, cursorState = cursorPos - 1, 1
                draw()
            elseif signal[4] == 205 and cursorPos < allLen - prefixLen + 1 then
                cursorPos, cursorState = cursorPos + 1, 1
                draw()
            elseif keys[29] and keys[46] then
                input = False
                break
            else
                cursorBlink(1)
            end
        elseif signal[1] == "key_up" then
            keys[signal[4]] = False
        elseif signal[1] == "clipboard" then
            input, cursorPos = input .. signal[3], cursorPos + unicodeLen(signal[3])
            draw()
        else
            cursorBlink()
        end
    end

    fill(1, y, width, 1, " ")
    return input
end,

function(...)
    local text, lines = {...}

    for i = 1, #text do
        text[i] = tostring(text[i])
    end

    lines = split(tableConcat(text, spaces), 1)

    for i = 1, #lines do
        gpu.copy(1, 1, width, height - 1, 0, -1)
        fill(1, height - 1, width, 1, " ")
        set(1, height - 1, lines[i])
    end
end

local function Error(err, func)
    if gpuAndScreen then
        status(err, "¯\\_(ツ)_/¯", mathHuge, 0, func or computerShutdown)
    else
        error(err)
    end
end

local boot, addBootCandidate, createElements =

function(bootImage)
    if bootImage[4] then
        status(bootFrom(bootImage, 1), False, .5)

        if eepromGetData() ~= bootImage[3] then
            eepromSetData(bootImage[3])
        end

        local success, err = execute(read(bootImage[1], bootImage[4]), "=" .. bootImage[4])

        if success then
            return 1
        else
            Error(err)
        end
    end
end,

function(address)
    local proxy = Select(2, Pcall(componentProxy, address))

    if proxy then
        tableInsert(bootCandidates, {proxy, proxy.getLabel() or undefined, address})

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                bootCandidates[#bootCandidates][4] = bootFiles[i]
                bootCandidates[#bootCandidates][5] = bootFiles[i]:gsub("/", "", 1)
                break
            end
        end
    end
end,

function(elements, y, drawSelectedItem, borderType, onArrowKeyUpOrDown)
    return {
        o = drawSelectedItem,
        a = onArrowKeyUpOrDown,
        e = elements,
        s = 1,
        d = function(Self)
            fill(1, y - 1, width, 3, " ")
            Self.s = ternary(Self.s > #Self.e, #Self.e, Self.s)
            checkAction(Self.e[Self.s].d, Self)
            local x, borderType, selectedItem = getCenterX(elementsLen(Self.e, borderType)), borderType == 1 and 1 or False

            for i = 1, #Self.e do
                selectedItem = Self.o and (i == Self.s and Foreground)

                if selectedItem then
                    fill(x - 3, y - ternary(borderType, 1, 0), Self.e[i].l + 6, ternary(borderType, 3, 1), " ", selectedItem)
                end

                set(x, y, Self.e[i].t, selectedItem, selectedItem and Background)
                x = x + Self.e[i].l + ternary(borderType, 6, 8)
            end
        end
    }
end

local function updateCandidates()
    bootCandidates = {}
    addBootCandidate(eepromGetData())
    for filesystem in pairs(componentList"fi") do
        if eepromGetData() ~= filesystem then
            addBootCandidate(filesystem)
        end
    end
end

updateCandidates()
if status("Press S to stay in bootloader", False, 1, 31) then
    local bootables, options, draw, signal

    bootables, draw = createElements({}, centerY - 2, 1, 1,
        function()
            options.o, options.s, bootables.o, selectedElement = 1, options.s or mathCeil(#options.e / 2), False, options
            bootables:d()
            options:d()
        end
    ), function()
        clear()
        center(height, "Use ← ↑ → keys to move cursor; Enter to do something; F5 to refresh")
        bootables:d()
        options:d()
    end

    for i = 1, #bootCandidates do
        tableInsert(bootables.e, {t = cutLabel(bootCandidates[i][2]), a = function(Self) boot(bootCandidates[Self.s]) end, d = function(Self)
            local proxy, label, readOnly = bootCandidates[Self.s][1]
            readOnly = proxy.isReadOnly()
            fill(1, centerY + 5, width, 3, " ")
            center(centerY + 5, bootFrom(bootCandidates[Self.s]), False, white)
            center(centerY + 7, ("Disk usage %s%% %s"):format(Math.floor(proxy.spaceUsed() / (proxy.spaceTotal() / 100)), ternary(readOnly, "R/O", "R/W")))

            options.e[4], options.e[5] = {t = "Rename", a =
            function()
                label = input(centerY + 9, 1, "New label: ")
                if label and label ~= "" then
                    proxy.setLabel(label)
                    label = cutLabel(label)
                    bootCandidates[bootables.s][2], bootables.e[bootables.s].t = label, label
                    bootables:d()
                end
            end}, ternary(not readOnly, {t = "Format", a =

            function()
                proxy.remove("/")
                bootables:d()
            end}, False)

            options:d()
        end})
    end

    options = createElements({
        {t = "Power Off", a = computerShutdown},
        {t = "Shell", a =
            function()

                local env, code = setmetatable({
                    print = print,
                    proxy = proxy,
                    sleep = function(timeout) sleep(timeout, 56) end
                }, {__index = _G})

                clear()
                ::loop::
                code = input(height, False, "> ")

                if code then
                    set(1, height, ">")
                    print(Select(2, execute(code, "=stdin", env)))
                    goto loop
                end
                draw()
            end
        },
        {t = "Recovery", a =
            function()
                local url, success, err = input(centerY + 9, 1, "Script URL: ")

                if url and url ~= "" then
                    center(centerY + 9, "Downloading...", Background, white)
                    success, err = execute(request(url) or "", "=recovery.lua")

                    if success then
                        draw()
                    else
                        Error(err, draw)
                    end
                end
            end
        }
    }, centerY + ternary(#bootCandidates >= 1, 2, 0), False, 0,
        function()
            options.o, bootables.o, selectedElement = False, 1, bootables
            bootables:d()
            options:d()
        end
    )
    selectedElement = bootables
    draw()

    while 1 do
        signal = {computerPullSignal()}

        if signal[1] == keyDown then
            if signal[4] == 203 and selectedElement.s > 1 then
                selectedElement.s = selectedElement.s - 1
                selectedElement:d()
            elseif signal[4] == 205 and selectedElement.s < #selectedElement.e then
                selectedElement.s = selectedElement.s + 1
                selectedElement:d()
            elseif signal[4] == 200 then
                checkAction(selectedElement.a, selectedElement)
            elseif signal[4] == 208 then
                checkAction(selectedElement.a, selectedElement)
            elseif signal[4] == 63 then
                updateCandidates()
                draw()
            elseif signal[4] == 28 then
                checkAction(selectedElement.e[selectedElement.s].a, selectedElement)
            end
        end
    end
end

for i = 1, #bootCandidates do
    boot(bootCandidates[i])
    computerShutdown()
end
Error("No bootable medium found")