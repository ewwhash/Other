local filesystem = require("filesystem")
local event = require("event")
local debug = require("component").debug
 
local timezone = 3 --Ваш часовой пояс, в моём случае GMT+3
local timestamp_update_in_seconds = 600 --Время обновления(в секундах)
 
local time_to_tick = {[00] = 18000, 19000, 20000, 21000, 22000, 23000, 24000, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000} --Не менять!
 
local function time()
  if require then
    local file = io.open("/tmp/time", "w")
    file:write("")
    file:close()
    return tonumber(string.sub(filesystem.lastModified("/tmp/time"), 1, 10)) + 3600 * timezone
  end
end
 
local timestamp = time()
local timestamp_update = timestamp + timestamp_update_in_seconds
debug.runCommand(" /gamerule doDaylightCycle false")
 
local function mc_time_update()
  timestamp = timestamp + 1
  mc_time = time_to_tick[tonumber(os.date("%H", timestamp))] + tonumber(os.date("%M", timestamp)) * 16.66666666666667
  if mc_time ~= mc_time_backup then
    debug.getWorld().setTime(mc_time)
    mc_time_backup = mc_time
  end
  if timestamp == timestamp_update then
    timestamp = time()
    timestamp_update = timestamp + timestamp_update_in_seconds
  end
end
 
event.timer(1, mc_time_update, math.huge)
