require("term").clear()
local component = require("component")
local event = require("event")
local unicode = require("unicode")
local inv, robot, redstone, chat = component.inventory_controller, component.robot, component.redstone, component.chat
local size = robot.inventorySize()
local teleports, oldDestination

local symbol, side, bufferSide = "?", 1, 3 --bufferSide - для версий выше 1.7
local version = "paper" --Версия работы - selector для 1.7, paper - для версией выше 1.7
local whiteList = {"Vasya", "Petya"} --Белый список игроков, другие игроки не смогут использовать телепорт

local function sort(a, b)
    return a.label < b.label
end

local function scan()
    teleports = {}
    local page, counter = 1, 0

    for slot = 1, size do 
        local item = inv.getStackInInternalSlot(slot)

        if item and (item.name == "EnderIO:itemCoordSelector" or item.name == "enderio:item_location_printout") then
            local teleport = #teleports + 1
            teleports[teleport] = {label = item.label, slot = slot}
            teleports[teleport].title = "§f'§a" .. teleports[teleport].label .. "§f'"
            teleports[teleport].page = page
            counter = counter + 1
            if counter == 8 then
                page, counter = page + 1, 0
            end
        end
    end

    teleports.pages = math.ceil(#teleports / 8)
    table.sort(teleports, sort)

    if #teleports == 0 then
        print("Ни одной точки не найдено!")
        os.exit()
    else
        print("Точек найдено: " .. #teleports)
    end
end

local function help()
    chat.say("§7Телепорт на точку: §c?tp §bточка§7.")
    chat.say("§7Список точек: §c?list §bстраница§7.")
    chat.say("§7Обновление точек: §c?update§7.")
end

local function activate()
    redstone.setOutput(side, 15)
    redstone.setOutput(side, 0)
end

local function teleportation(teleport)
    chat.say("§7Подготовка к телепортации на '§a" .. teleports[teleport].label .. "§7'...")
    robot.select(teleports[teleport].slot)

    if version == "selector" then
        inv.equip()
        robot.use(side, true)
        activate()
        inv.equip()
    elseif version == "paper" then
        robot.drop(side)
        activate()
        counter = 0

        while true do 
            local item = inv.getStackInSlot(bufferSide, 1)
            counter = counter + 1

            if item and (item.name == "enderio:item_location_printout") then --как же с этого горит, ну почему нельзя из телепорта достать распечатку?!
                robot.suck(bufferSide)
                break
            end

            print("Попытка поиска распечатки #" .. counter)
            os.sleep(0)
        end
    end

    robot.select(1)
end

local function findDestination(destination)
    if destination then
        destination = unicode.lower(destination)
        local found

        for teleport = 1, #teleports do 
            if unicode.sub(unicode.lower(teleports[teleport].label), 1, unicode.len(destination)) == destination then 
                teleportation(teleport)
                oldDestination = teleport
                found = true
                break
            end
        end

        if not found then 
            chat.say("§cТочки " .. destination ..  " не существует!")
            help()
        end
    elseif oldDestination then 
        teleportation(oldDestination)
    else
        help()
    end
end

local function list(page)   
    if page then 
        page = tonumber(page)

        if not page then 
            help()
        else
            page = math.floor(page)
        end
    else
        page = 1
    end

    if page then
        if page > teleports.pages then 
            chat.say("§cВсего " .. teleports.pages .. " страниц.")
        else
            chat.say("§6§lТочки - Страница " .. page .. "/" .. teleports.pages)
            for teleport = 1, #teleports do
                if teleports[teleport].page == page then
                    chat.say(teleports[teleport].title)
                end
            end
        end
    end
end

local cmd = {
    help = help,
    tp = findDestination,
    list = list,
    update = scan
}

for user = 1, #whiteList do 
    whiteList[whiteList[user]], whiteList[user] = true, nil
end 
robot.select(1)
scan()

while true do 
    local evt = {event.pull()}

    if evt[1] == "chat_message" and whiteList[evt[3]] then
        chat.setName("§eTelepad§7§o")
        if evt[4]:sub(1, 1) == symbol then
            local message = evt[4]:sub(2, #evt[4])
            local args = {}

            for part in message:gsub("^(.-)%s*$", "%1"):gmatch("%s*([^%s]+)") do 
                args[#args+1]=("%q"):format(part):gsub('"', '')
            end 

            if cmd[args[1]] then 
                cmd[args[1]](table.unpack(args, 2, #args))
            else
                help()
            end
        end
    end
end
