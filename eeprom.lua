
local bootFiles, Component, Computer, Table, Background, Foreground, white, bootCandidates, False, gpuAndScreen, width, height, centerY = {
    "/init.lua"
}, component, computer, table, 0x062b34, 0x839ea9, 0xffffff

local componentProxy, componentList, computerPullSignal, mathHuge, mathCeil, tableInsert = Component.proxy, Component.list, Computer.pullSignal, math.huge, math.ceil, Table.insert

local function proxy(componentType)
    local address = componentList(componentType)()
    return address and componentProxy(address)
end

local gpu, eeprom, internet, screen, tmpfs = proxy"gp" or {}, proxy"pr", proxy"in", proxy"sc", componentProxy(Computer.tmpAddress())
local gpuSetBackground, gpuSetForeground, eepromGetData, eepromSetData, computerShutdown = gpu.setBackground, gpu.setForeground, eeprom.getData, eeprom.setData, computer.shutdown

if gpuSetBackground and screen then
    gpu.bind((componentList"sc"()))
    gpuAndScreen, width, height = 1, gpu.maxResolution()
    centerY = height / 2
    gpu.setResolution(width, height)
end

computer.getBootAddress = function()
    return eepromGetData()
end

computer.setBootAddress = function(address)
    eepromSetData(address)
end

local request, execute, read =

function(...) -- request()
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

function(...) -- execute()
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

function(proxy, file) -- read()
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

local set, fill =

function(x, y, str, background, foreground)
    gpuSetBackground(background or Background)
    gpuSetForeground(foreground or Foreground)
    gpu.set(x, y, str)
end,

function(x, y, width, height, symbol, background, foreground)
    gpuSetBackground(background or Background)
    gpuSetForeground(foreground or Foreground)
    gpu.fill(x, y, width, height, symbol)
end

local clear, center = 

function() -- clear()
    fill(1, 1, width, height, " ", 0x002b36)
end,

function(y, str, background, foreground) -- center()
    set(mathCeil(width / 2 - unicode.len(str) / 2), y, str, background, foreground)
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

        while wait do
            local signal = {computerPullSignal(wait)}

            if signal[1] == "key_down" and (not breakCode or signal[4] == breakCode) then
                if onBreak then
                    onBreak()
                end
                wait = False
            end
        end
    end
end

local function Error(err)
    if gpuAndScreen then
        status(err, "¯\\_(ツ)_/¯", mathHuge, False, computerShutdown)
    else
        error(err)
    end
end

local boot, addBootCandidate =

function(proxy, file) -- boot()
    status("Booting from " .. (proxy.getLabel() or "Undefined") .. "...")

    if eepromGetData() ~= proxy.address then
        eepromSetData(proxy.address)
    end

    local success, err = execute(read(proxy, file), "=" .. file:gsub("/", ""))

    if success then
        return 1
    else
        Error(err)
    end
end,

function(address) -- addBootCandidate()
    local proxy = select(2, pcall(componentProxy, address))

    if proxy then
        tableInsert(filesystems, proxy)

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                tableInsert(bootCandidates, {proxy, bootFiles[i]})
            end
        end
    end
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
clear()
center(centerY - 5, "Select OS to boot", False, white)
fill(width / 2 - 4, centerY, 8, 3, " ", 0x303435)
set(width / 2 - 3, centerY + 1, "OpenOS", 0x303435)

while 1 do
    local signal = {computerPullSignal()}

    if signal[1] == "key_down" then
    end
end

if #bootCandidates >= 1 then
    boot(bootCandidates[1][1], bootCandidates[1][2])
else
    Error("No bootable medium found")
end