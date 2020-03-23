local bootFiles, Component, Computer, Table, Math, Unicode, Background, Foreground, white, gray, keyDown, bootCandidates, False, gpuAndScreen, width, height, centerY, computerShutdown, selectedElement = {
    "/init.lua",
    "/OS.lua"
}, component, computer, table, math, unicode, 0x002b36, 0x8cb9c5, 0xffffff, 0x292929, "key_down"

local componentProxy, componentList, computerPullSignal, computerUptime, mathHuge, mathCeil, tableInsert, unicodeLen, unicodeSub = Component.proxy, Component.list, Computer.pullSignal, computer.uptime, Math.huge, Math.ceil, Table.insert, Unicode.len, Unicode.sub

local function proxy(componentType)
    local address = componentList(componentType)()
    return address and componentProxy(address)
end

local gpu, eeprom, internet, screen, tmpfs = proxy"gp" or {}, proxy"pr", proxy"in", proxy"sc", componentProxy(Computer.tmpAddress())
local gpuSetBackground, gpuSetForeground, gpuSetPaletteColor, eepromGetData, eepromSetData = gpu.setBackground, gpu.setForeground, gpu.setPaletteColor, eeprom.getData, eeprom.setData
computer.getBootAddress = eepromGetData
computer.setBootAddress = eepromSetData
computerShutdown = function()
    computer.shutdown()
end

if gpuSetBackground and screen then
    gpu.bind((componentList"sc"()))
    gpuAndScreen, oldPalette, width, height = 1, gpu.getPaletteColor(9), gpu.maxResolution()
    centerY = height / 2
    gpuSetPaletteColor(9, Background)
    gpu.setResolution(width, height)
end

local request, execute, read =

function(...)
    if internet then
        local handle, data, chunk = internet.request(...), ""

        if not handle then
            return
        end

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

function(...)
	local chunk, err = load(...)

	if not chunk and err then
		return False, err
	else
		local data = {xpcall(chunk, debug.traceback)}

		if data[1] then
			return 1, Table.unpack(data, 2, data.n)
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
end

local set, fill, getCenterX =

function(x, y, str, background, foreground)
    gpuSetBackground(background or Background)
    gpuSetForeground(foreground or Foreground)
    gpu.set(x, y, str)
end,

function(x, y, width, height, symbol, background, foreground)
    gpuSetBackground(background or Background)
    gpuSetForeground(foreground or Foreground)
    gpu.fill(x, y, width, height, symbol)
end,

function(len)
    return mathCeil(width / 2 - len / 2)
end

local clear, center, sleep, bootFrom, elementsLen, checkAction = 

function()
    fill(1, 1, width, height, " ", Background)
end,

function(y, str, background, foreground)
    set(getCenterX(unicodeLen(str)), y, str, background, foreground)
end,

function(timeout, breakCode, onBreak)
    local deadline = computerUptime() + (timeout or 0)
    repeat
        local signal = {computerPullSignal(deadline - computerUptime())}

        if signal[1] == keyDown and (breakCode == 0 or signal[4] == breakCode) then
            if onBreak then
                onBreak()
            end
            return 1
        end
    until computerUptime() >= deadline
end,

function(bootImage, alreadyBooting)
    return("Boot%s %s from %s (%s)"):format(alreadyBooting and "ing" or "", bootImage[4], bootImage[2], alreadyBooting and bootImage[5] or unicodeSub(bootImage[5], 1, 3) .. "…")
end,

function(elements, border)
    local allLen = 0

    for i = 1, #elements do
        local len = unicodeLen(elements[i].t)
        allLen, elements[i].l = allLen + len + (i == #elements and 0 or (border == 1 and 8 or 10)), len
    end

    return allLen
end,

function(action, Self)
    if action and type(action) == "function" then
        action(Self)
    end
end

local function status(str, title, wait, breakCode, onBreak)
    if gpuAndScreen then
        local lines = {}

        for line in str:gmatch"[^\r\n]+" do
            lines[#lines + 1] = line:gsub("\t", "")
        end

        local y = mathCeil(centerY - #lines / 2) + 1
        clear()
        if title then
            center(y - 1, title, Background, white)
            y = y + 1
        end

        for i = 1, #lines do
            center(y, lines[i], Background, Foreground)
            y = y + 1
        end

        return sleep(wait, breakCode, onBreak)
    end
end

local Error, candidateSelected = 

function(err)
    if gpuAndScreen then
        status(err, "¯\\_(ツ)_/¯", mathHuge, False, computerShutdown)
    else
        error(err)
    end
end,

function(options, selected)
    options.e[4], options.e[5] = {t = "Rename"}, {t = "Format"}
    fill(1, centerY + 6, width, 3, " ", Background)
    center(centerY + 6, bootFrom(bootCandidates[selected]), False, white)
    center(centerY + 8, "Disk usage ")
    options:d()
end

local boot, addBootCandidate, createElements =

function(bootImage)
    status(bootFrom(bootImage, 1), False, .5)

    if eepromGetData() ~= bootImage[5] then
        eepromSetData(bootImage[5])
    end

    local success, err = execute(read(bootImage[1], bootImage[3]), "=" .. bootImage[4])

    if success then
        return 1
    else
        Error(err)
    end
end,

function(address)
    local proxy = select(2, pcall(componentProxy, address))

    if proxy then
        tableInsert(bootCandidates, {proxy, proxy.getLabel() or "undefined", address, bootFiles[i], bootFiles[i]:gsub("/", "", 1)})

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                tableInsert(bootCandidates, {proxy, proxy.getLabel() or "undefined", bootFiles[i], bootFiles[i]:gsub("/", "", 1), address})
                break
            end
        end
    end
end,

function(elements, y, selected, border, onArrowKeyUpOrDown)
    return {
        a = onArrowKeyUpOrDown, 
        w = 1,
        e = elements,
        s = selected or 0,
        d = function(Self)
            local x, bigBorder = getCenterX(elementsLen(Self.e, border)), border == 1 and 1
            x = bigBorder and x or x - 1
            fill(1, y - (bigBorder and 1 or 0), width, (bigBorder and 3 or 1), " ")

            for i = 1, #Self.e do
                local selectedItem = i == Self.s and gray

                if selectedItem then
                    fill(x - 3, y - (bigBorder and 1 or 0), Self.e[i].l + 6, (bigBorder and 3 or 1), " ", selectedItem)
                end

                set(x, y, Self.e[i].t, selectedItem, Foreground)
                x = x + Self.e[i].l + (bigBorder and 8 or 10)
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

local function main()
    local bootables, options
    bootables, options = createElements({}, centerY - 2, 1, 1, function() options.s, selectedElement = mathCeil(#options.e / 2) , options options:d() end)
    for i = 1, #bootCandidates do
        local label = bootCandidates[i][2]
        if unicodeLen(label) > 8 then
            label = unicodeSub(label, 1, 6) .. "…"
        end
        tableInsert(bootables.e, {t = label, a = function(Self) boot(bootCandidates[Self.s]) end, o = function(Self) candidateSelected(options, Self.s) end})
    end
    options, selectedElement = createElements({
        {t = "Power Off", a = computerShutdown},
        {t = "Shell"},
        {t = "Recovery"},
    }, centerY + (#bootCandidates >= 1 and 2 or 0), 0, 0, function() selectedElement = bootables options:d() bootables:d() end), bootables
    clear()
    if #bootCandidates >= 1 then
        candidateSelected(options, 1)
    end
    center(height, "Use ← ↑ → keys to move cursor; Enter to do something; F5 to refresh")
    bootables:d()
    options:d()
end

updateCandidates()
if status("Press S to stay in bootloader", False, 1, 31) then
    main()
    while 1 do
        local signal = {computerPullSignal()}

        if signal[1] == keyDown then
            if signal[4] == 203 and selectedElement.s > 1 then
                selectedElement.s = selectedElement.s - 1
                selectedElement:d()
                checkAction(selectedElement.e[selectedElement.s].o, selectedElement)
            elseif signal[4] == 205 and selectedElement.s < #selectedElement.e then
                selectedElement.s = selectedElement.s + 1
                selectedElement:d()
                checkAction(selectedElement.e[selectedElement.s].o, selectedElement)
            elseif signal[4] == 200 then
                checkAction(selectedElement.a, selectedElement, 1)
            elseif signal[4] == 208 then
                checkAction(selectedElement.a, selectedElement, False)
            elseif signal[4] == 63 then
                updateCandidates()
                main()
            elseif signal[4] == 28 then
                checkAction(selectedElement.e[selectedElement.s].a, selectedElement)
            end
        end
    end
end

if #bootCandidates >= 1 then
    boot(bootCandidates[1])
else
    Error("No bootable medium found")
end