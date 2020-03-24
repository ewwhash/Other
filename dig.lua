local function exit()
    turnToSide, moveTo = nil, nil
    os.exit()
end
local args = {...}
local sizeX, sizeY, sizeZ = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
if not sizeX or not sizeY or not sizeZ then
    print("usage: dig <x> <y> <z>")
    exit()
end
local layers = math.floor(sizeY / 3)
local correction = sizeY % 3
sizeX, sizeY, sizeZ = sizeX - 1, sizeY - 1, sizeZ - 1

local component = require("component")
local computer = require("computer")
local robot = component.robot
local X, Y, Z, compass = 0, 0, 0, 0
local invSize = robot.inventorySize()
local onePercentCharge = computer.maxEnergy() / 100
local ignoreCheck = false
local generators = {}

for address in component.list("generator") do
    table.insert(generators, address)
end

local function toolDurability()
    local durability, err = robot.durability()

    if durability then
        return durability / 0.01
    elseif err == "tool cannot be damaged" then
        return 100
    else
        return 0
    end
end

local function fillUpGenerators()
    for generator = 1, #generators do
        component.invoke(generators[generator], "insert")
    end
end

local function autoFillUpGenerators()
    for slot = 1, invSize do
        robot.select(slot)
        fillUpGenerators()
    end
    robot.select(1)
end

local function unloadInventory()
    turnToSide(3)
    for slot = 1, invSize do
        robot.select(slot)
        fillUpGenerators()
        if not robot.drop(3) and robot.count(slot) > 1 then
            print("External inventory's is full! Job aborting...")
            turnToSide(0)
            exit()
        end
    end
    robot.select(1)
end

local function waitCharge()
    while math.ceil(computer.energy() / onePercentCharge) < 100 do
        os.sleep(math.huge)
    end
end

local function home(exit)
    ignoreCheck = true
    moveTo(0, 0, 0)
    unloadInventory()
    if not exit then
        waitCharge()
    end
    turnToSide(0)
    ignoreCheck = false
end

local function abort(reason)
    print(reason)
    home(exit)
    exit()
end

local function check()
    if robot.count(invSize) > 0 then
        local x, y, z, c = X, Y, Z, compass
        home()
        moveTo(x, y, z)
        turnToSide(c)
    end
    local charge = computer.energy() / onePercentCharge

    if charge < 10 then
        home("Robot charge below 10 percent, return to base...")
    elseif charge < 25 then
        print("Filling up generators...")
        autoFillUpGenerators()
    end
    if toolDurability() < 5 then
        abort("Tool durability below 5 percent, return to base...")
    end
end

local function swing(side)
    if robot.detect(side) and not robot.swing(side) then
        abort("Warning! Indestructible block detected at: \nX: " .. X .. " Y: " .. Y .. "  Z:" .. Z .. "\n")
    end
end

local function move(side, digDown, digUp)
    swing(side)
    if side ~= 1 and digUp then
        swing(1)
    end
    if side ~= 0 and digDown then
        swing(0)
    end
    while not robot.move(side) do swing(side) end
    if side == 3 then
        if compass == 0 then
            X = X + 1
        elseif compass == 1 then
            Z = Z + 1
        elseif compass == 2 then
            X = X - 1
        elseif compass == 3 then
            Z = Z - 1
        end
    elseif side == 1 then
        Y = Y + 1
    else
        Y = Y - 1
    end
    if not ignoreCheck then
        check()
    end
end        

local function moveBySteps(side, steps, digDown, digUp)
    steps = math.abs(steps)
    for i = 1, steps do
        move(side, steps, digDown, digUp)
        swing(1)
        swing(0)
    end
end

local function turn(clockwise)
    while not robot.turn(clockwise) do computer.shutdown() end
    compass = clockwise and (compass == 3 and 0 or compass + 1) or (compass == 0 and 3 or compass - 1)
end

function turnToSide(side)
    while compass ~= side do
        turn((side - compass) % 4 == 1)
    end
end

function moveTo(x, y, z)
    if Y > y then
        while Y ~= y do move(0) end
    elseif Y < y then
        while Y ~= y do move(1) end
    end
    if X > x then
        turnToSide(2)
    elseif X < x then
        turnToSide(0)
    end
    while X ~= x do
        move(3)
    end
    if Z > z then
        turnToSide(3)
    elseif Z < z then
        turnToSide(1)
    end
    while Z ~= z do
        move(3)
    end
end

local function layeredMove(turnRight, turnLeft, digDown, digUp)
    for z = 0, sizeZ do
        moveBySteps(3, sizeX, digDown, digUp)

        if z ~= sizeZ then
            if compass == 0 then
                turn(turnRight)
                move(3, digDown, digUp)
                turn(turnRight)
            else
                turn(turnLeft)
                move(3, digDown, digUp)
                turn(turnLeft)
            end
        end
    end
end

local function correctionDig(turnRight, turnLeft)
    moveBySteps(correction - 1)
    layeredMove(turnRight, turnLeft, true, false)
end

if invSize == 0 then
    print("Need inventory upgrade!")
    exit()
elseif toolDurability() == 0 then
    print("Need new tool!")
    exit()
end

require("process").info().data.signal = function() print("Job aborting...") exit() end
autoFillUpGenerators()
swing(0)
local time = computer.uptime()

if layers == 0 and correction > 0 then
    correctionDig(true, false)
else
    moveBySteps(0, 2)

    for lay = 1, layers do
        local turnRight = lay % 2 == 1
        layeredMove(turnRight, not turnRight, true, true)
        turnToSide(compass == 0 and 2 or 0)

        if lay == layers and correction > 0 then
            move(0)
            correctionDig(not turnRight, turnRight)
        elseif lay ~= layers then
            moveBySteps(0, 3)
            swing(0)
        end
    end
end

abort("Work completed in " .. os.date("%H hour %M minute %S seconds", computer.uptime() - time) .. " \nReturn to base...")