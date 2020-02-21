local logTimezone = 1 --Часовой пояс сервера
local userTimezone = 3 --Ваш часовой пояс
local timerUpdateFilename = 600 --в секундах
local link = "https://logs.s7.mcskill.ru/Hitechcraft_Public_Logs/public_logs/Hitechcraft_Public_Logs/" --Ссылка на логи
------------------------------------------------------------------------------------------------------------------------
local component = require("component")
local filesystem = require("filesystem")
local unicode = require("unicode")
local computer = require("computer")
local gpu = component.gpu
local internet = component.internet
local readed, eTag = 0
local fullLink, filename, nextUpdate
local w, h = gpu.getResolution()
local corrList = {
    1 = 0,
    2 = -1700,
    3 = 1700
}

local function getTimestamp(timezone)
	local file = io.open("/tmp/time", "w")
	file:write("time")
	file:close() 
    return filesystem.lastModified("/tmp/time") / 1000 + 3600 * timezone
end

local function request(path, post, headers, method)
    local handle, data, chunk = internet.request(path, post, headers, method), ""

    while true do
        chunk = handle.read()

        if chunk then
            data = data .. chunk
        else
            break
        end
    end
     
    return data, handle.response()
end

local function updateFilename()
    local correction, timestamp, code, message, headers = 0, getTimestamp(logTimezone)

    for i = 1, 3 do
        correction = corrList[i]
        filename = os.date("%d-%m-%Y.txt", timestamp - correction)
        code, message, headers = select(2, request(link .. filename, nil, nil, "HEAD"))

        if code and code == 200 then
            break
        elseif correction >= 1700 then
            error("Error on attempt get new file name " .. tostring(code) .. " " .. tostring(message))
        end
    end

    fullLink, readed, eTag = link .. filename, headers["Content-Length"][1], headers["ETag"][1]
end

local function updateVariables()  
    nextUpdate = computer.uptime() + 600
    updateFilename()
end

require("term").clear()
updateVariables()

while true do
    if computer.uptime() >= nextUpdate then
        updateVariables() 
    end

    for i = 1, 5 do 
        local code, message, headers = select(2, request(fullLink, nil, nil, "HEAD"))

        if code and code == 200 then
            if eTag ~= headers["ETag"][1] then
                local data, code, message, headers = request(fullLink, nil, {Range = ("bytes=%d-"):format(readed)})

                if data ~= "" then
                    readed, eTag = readed + #data, headers["ETag"][1]
                    local formatted = data:gsub("%d+:%d+:%d+", os.date("%H:%M:%S", getTimestamp(userTimezone)))
                    io.write(formatted)
                end
            end

            break
        elseif i == 5 then
            error("Web server is down!")
        end
    end

    os.sleep(0)
end
