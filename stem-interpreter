component = require("component")
serialization = require("serialization")
event = require("event")
channel = ""
 
if component.isAvailable("internet") then
  server = require("stem").connect("stem.fomalhaut.me")
  server:subscribe(channel)
else
  os.exit()
end
 
function concat(tbl)
    for i = 1, tbl.n do
        if type(tbl[i]) == "table" then
            tbl[i] = serialization.serialize(tbl[i], true) .. "\t"
        else
            tbl[i] = tostring(tbl[i])
        end
    end
 
    return table.concat(tbl, ",  ")
end
 
function prt(...)
  data = table.pack(...)
  server:send(channel, concat(data))
end
 
function runCode(code)
  chunk = load("return " .. code, "=stdin", "t")
 
  if not chunk then
    chunk, err = load(code, "=stdin", "t")
 
    if not chunk then
      server:send(channel, "Syntax error: " .. err)
      return false
    end
  end
 
  data = table.pack(pcall(chunk))
 
  if data[1] then
    if data.n > 1 then
      table.remove(data, 1)
      data.n = data.n - 1
      server:send(channel, concat(data))
    end
  else
    server:send(channel, data[2])
  end
end
 
event.listen("stem_message", function(...)
  data = {...}
  runCode(data[3])
end)
 
event.timer(15, function()
  if not server:isConnected() or not server:ping("PING") then
    server = server:reconnect()
    server:subscribe(channel)
  end
end, math.huge)
