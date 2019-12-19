whiteList = {"ewwhash", "Chesh1r3", "NemoCrazy87", "hohserg"} --Белый список, другие игроки не смогут использовать телепорт
symbol = "?" --Префикс команд
side = 3 --Сторона, в которой стоит телепорт
bufferSide = 3 --Для версий выше 1.7
ejectSide = 1 --Сторона, из которой будут извлекаться точки
version = "selector" --Версия работы - selector для 1.7, paper - для версий выше 1.7

local function proxy(componentType)
    return component.proxy(component.list(componentType)())
end

local inv, robot, redstone, chat, magnet = proxy("inventory_controller"), proxy("robot"), proxy("redstone"), proxy("chat"), proxy("tractor_beam")
local size = robot.inventorySize()
local teleports, allPages, allTeleports, oldlabel = {}, 1, 0

local function sort(a, b)
    return a.label < b.label
end

local function garbage(label, slot)
    robot.select(slot)
    chat.say("§7Выкидываю мусор: '§a" .. label .. "§7'...")
    robot.drop(0)
    robot.select(1)
end

local function newPoint(slot, say)
    local item = inv.getStackInInternalSlot(slot)

    if item then 
        if item.name == "EnderIO:itemCoordSelector" or item.name == "enderio:item_location_printout" then
            local teleport = #teleports + 1
            teleports[teleport] = {label = item.label, slot = slot}
            teleports[teleport].title = "§f'§a" .. item.label .. "§f'"
            teleports[teleport].page = allPages
            allTeleports = allTeleports + 1
            if allTeleports == 8 then
                allPages, allTeleports = allPages + 1, 0
            end
            table.sort(teleports, sort)

            if say then
                chat.say("§7Обнаружена новая точка '§a" .. item.label .. "§7'!")
            end
        else
            garbage(item.label, slot)
        end
    end
end

local function scan()
    teleports = {}
    local page, counter = 1, 0

    for slot = 1, size do 
        newPoint(slot)
    end

    chat.say("Сканирование завершено. Точек найдено: " .. #teleports)
end

local function help()
    chat.say("§7Телепорт на точку: §c?tp §bточка§7.")
    chat.say("§7Список точек: §c?list §bстраница§7.")
    chat.say("§7Извлечь точку: §c?eject §bточка§7.")
    chat.say("§7Добавление точки: §c?addpoint§7.")
    chat.say("§7Обновление точек: §c?update§7.")
end

local function activate()
    redstone.setOutput(side, 15)
    os.sleep(.1)
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

            if counter == 500 then 
                chat.say("§cНе могу достать распечатку!")
                counter = 0
            end
            os.sleep(0)
        end
    end

    robot.select(1)
end

local function find(label)
    local found = false
    local len = unicode.len(label)

    for teleport = 1, #teleports do 
        if unicode.sub(unicode.lower(teleports[teleport].label), 1, len) == label then 
            found = teleport
            break
        end
    end

    if found then
        return found
    else
        chat.say("§cТочки " .. label ..  " не существует!")
    end
end

local function prepareTeleportation(label)
    if label then
        label = unicode.lower(label)
        local teleport = find(label)

        if teleport then
            oldlabel = label
            teleportation(teleport)
        else 
            help()
        end
    elseif oldlabel then 
        teleportation(oldlabel)
    else
        help()
    end
end

local function addPoint() 
    if magnet.suck() then
        local changed, slot = event.pull(.3, "inventory_changed")

        if changed then 
            newPoint(slot, true)
        end
    end
end

local function eject(label)
    if label then 
        local teleport = find(unicode.lower(label))

        if teleport then
            chat.say("§7Извлечение точки '§a" .. teleports[teleport].label .. "§7'...")
            robot.select(teleports[teleport].slot)
            robot.drop(ejectSide)
            robot.select(1)
            table.remove(teleports, teleport)
        end
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
        if page > allPages then 
            chat.say("§cВсего " .. allPages .. " страниц.")
        else
            chat.say("§6§lТочки - Страница " .. page .. "/" .. allPages)
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
    tp = prepareTeleportation,
    list = list,
    update = scan,
    addpoint = addPoint,
    eject = eject
}

for user = 1, #whiteList do 
    whiteList[whiteList[user]], whiteList[user] = true, nil
end 
robot.select(1)
chat.setName("§eTelepad§7§o")
scan()

while true do 
    local evt = {computer.pullSignal()}

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
