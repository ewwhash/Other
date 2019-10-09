local robot = require("component").robot
local size_x, size_z = 16, 16
local x, z = 1, 1

local function move(side)
	if robot.detect(side) then robot.use(side) end 
    while not robot.move(side) do end
end

local function shot()
	while not robot.use(0) do end
	while not robot.use(1) do end 
end

local function dig()
	robot.use(0)
    while true do
        if x == size_x and z == size_z or x == 1 and z == size_z and z % 2 == 0 then
            os.exit()
        elseif x == size_x or x == 1 and z > 1 then 
            if z % 2 == 1 then
                robot.turn(true)
                move(3)
                robot.turn(true)
            else
                robot.turn(false)
                move(3)
                robot.turn(false)
            end
            shot()
            z = z + 1 
        end
        if z % 2 == 1 then
            x = x + 1
        else
            x = x - 1 
        end
        move(3)
        shot()
    end
end
dig()
