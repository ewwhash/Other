local bootFiles, Component, Computer, Table, Math, Background, Foreground, white, keyDown, bootCandidates, False, gpuAndScreen, width, height, centerY = {
    "/init.lua"
}, component, computer, table, math, 0x002b36, 0x8cb9c5, 0xffffff, "key_down"

local componentProxy, componentList, computerPullSignal, computerUptime, mathHuge, mathCeil, tableInsert = Component.proxy, Component.list, Computer.pullSignal, computer.uptime, Math.huge, Math.ceil, Table.insert

local function proxy(componentType)
    local address = componentList(componentType)()
    return address and componentProxy(address)
end

local gpu, eeprom, internet, screen, tmpfs = proxy"gp" or {}, proxy"pr", proxy"in", proxy"sc", componentProxy(Computer.tmpAddress())
local gpuSetBackground, gpuSetForeground, eepromGetData, eepromSetData, computerShutdown = gpu.setBackground, gpu.setForeground, eeprom.getData, eeprom.setData, computer.shutdown
computer.getBootAddress = eepromGetData
computer.setBootAddress = eepromSetData

if gpuSetBackground and screen then
    gpu.bind((componentList"sc"()))
    gpuAndScreen, width, height = 1, gpu.maxResolution()
    centerY = height / 2
    gpu.setPaletteColor(9, 0x002b36)
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

local clear, center, sleep, bootFrom, elementsLen = 

function()
    fill(1, 1, width, height, " ", 0x002b36)
end,

function(y, str, background, foreground)
    set(getCenterX(unicode.len(str)), y, str, background, foreground)
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

function(proxy, file, alreadyBooting)
    return("Boot%s %s from %s (%s)"):format(alreadyBooting and "ing" or "", file, proxy.getLabel() or "undefined", proxy.address)
end,

function(elements)
    local allLen = 0

    for i = 1, #elements do
        local len = unicode.len(elements[i].t)
        allLen, elements[i].l = allLen + len + (i == #elements and 0 or 8), len
    end

    return allLen
end

local function status(str, title, wait, breakCode, onBreak)
    if gpuAndScreen then
        local lines = {}

        for line in str:gmatch"[^\r\n]+" do
            lines[#lines + 1] = line:gsub("\t", "")
        end

        local y = mathCeil(centerY - #lines / 2)
        clear()
        if title then
            center(y - 1, title, False, white)
            y = y + 1
        end

        for i = 1, #lines do
            center(y, lines[i])
            y = y + 1
        end

        return sleep(wait, breakCode, onBreak)
    end
end

local function Error(err)
    if gpuAndScreen then
        status(err, "¯\\_(ツ)_/¯", mathHuge, False, computerShutdown)
    else
        error(err)
    end
end

local boot, addBootCandidate, menu =

function(proxy, file, prettyViewFile)
    status(bootFrom(proxy, prettyViewFile, 1), False, .5)

    if eepromGetData() ~= proxy.address then
        eepromSetData(proxy.address)
    end

    local success, err = execute(read(proxy, file), "=" .. prettyViewFile)

    if success then
        return 1
    else
        Error(err)
    end
end,

function(address)
    local proxy = select(2, pcall(componentProxy, address))

    if proxy then
        tableInsert(filesystems, proxy)

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                tableInsert(bootCandidates, {proxy, bootFiles[i], bootFiles[i]:gsub("/", "", 1)})
            end
        end
    end
end,

function(elements, y, actionOnDraw, actionOnArrowKeyUp, actionOnArrowKeyDown, actionOnF5)
    local globalX, selected, action = getCenterX(elementsLen(elements)), 1,

    function(checkAction, Self)
        if checkAction and type(checkAction) == "function" then
            checkAction(Self)
        end
    end

    return {
        d = function()
            local x = globalX
            clear()

            for i = 1, #elements do
                local selectedItem = i == selected and 0x292929

                if selectedItem then
                    fill(x - 3, y, elements[i].l + 6, 1, " ", selectedItem)
                end

                set(x, y, elements[i].t, selectedItem)
                x = x + elements[i].l + 8
            end

            action(actionOnDraw)
        end,
        l = function(Self)
            while 1 do
                local signal = {computerPullSignal()}

                if signal[1] == keyDown then
                    if signal[4] == 203 and selected > 1 then
                        selected = selected - 1
                        Self:d()
                    elseif signal[4] == 205 and selected < #elements then
                        selected = selected + 1
                        Self:d()
                    elseif signal[4] == 200 then
                        action(actionOnArrowKeyUp, Self)
                    elseif signal[4] == 208 then
                        action(actionOnArrowKeyDown, Self)
                    elseif signal[4] == 63 then
                        action(actionOnF5, Self)
                    elseif signal[4] == 28 then
                        action(elements[selected].a, Self)
                    end
                end
            end
        end
    }
end

local function updateCandidates()
    bootCandidates, filesystems = {}, {}
    addBootCandidate(eepromGetData())
    for filesystem in pairs(componentList"fi") do

        if eepromGetData() ~= filesystem then
            addBootCandidate(filesystem)
        end
    end
end

updateCandidates()
if status("Press F9 to stay in bootloader", False, .8, 67) then
    local main = menu({
        {t = "Power Off", a = computerShutdown},
        {t = "Settings"},
        {t = "Shell"},
        {t = "Recovery"}
    }, centerY + 5, function() center(height, "Use ← ↑ → keys to move cursor; Enter to do something; F5 to refresh") end, False, False, function(Self) updateCandidates() Self:d() end)
    main:d()
    main:l()
end

if #bootCandidates >= 1 then
    boot(bootCandidates[1][1], bootCandidates[1][2], bootCandidates[1][3])
else
    Error("No bootable medium found")
end