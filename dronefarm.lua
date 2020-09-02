sizeX, sizeZ = 19, 10 -- The size of farm (X and Z)
height = 2 -- Height above ground
wait = 300 -- Delay (In seconds)
waitCharge = 15 -- Waiting for charge (In seconds too)
waitMove = .1 -- Delay from moving block to block
backOnCharge = 20 -- Fallback percent to home
compass = "SOUTH" -- Direction (Drone "front")
mode = "SWING" -- Working mode (SWING/USE)
place = false -- Place plant after breaking (Only for SWING mode)

d, c = component.proxy(component.list("drone")()), computer

status = {
    collect = {text = "COLLECTING", color = 0xe8e81e},
    idle = {text = "IDLE", color = 0xffffff},
    charge = {text = "CHARGING", color = 0x64ea12}
}
   
function sleep(timeout)
    deadline = c.uptime() + timeout

    repeat
        c.pullSignal(deadline - c.uptime())
    until c.uptime() >= deadline
end
 
function slow(timeout) 
    while d.getOffset() > .5 do 
        sleep(timeout)
    end
end

function move(x, y, z)
    if compass == "NORTH" then
        d.move(z, y, -x)
    elseif compass == "SOUTH" then
        d.move(-z, y, x)
    elseif compass == "WEST" then 
        d.move(-x, y, -z)
    else
        d.move(x, y, z)
    end

    slow(waitMove)
end
 
function home()
    move(-x, 0, -z)
    move(0, -height + 1, -1)
    slow(2)

    for slot = place and 2 or 1, d.inventorySize() do
        d.select(slot)

        while not d.drop(0) do 
            if d.count(slot) == 0 then 
                break 
            end 
        end 
    end

    d.select(1)
    move(0, -1, 1)
end
 
function back()
    move(x, height, z)
end

function start(left)
    move(1, height, 1)
    collect()
end

function checkEnergy()
    if c.energy() <= backOnCharge * (c.maxEnergy() / 100) then
        home()
        d.setStatusText(status.charge.text)
        d.setLightColor(status.charge.color)
        sleep(waitCharge)

        if c.energy() <= backOnCharge * (c.maxEnergy() / 100) then
            d.setStatusText("OUT OF\nENERGY")
            c.shutdown()
        else
            d.setStatusText(status.collect.text)
            d.setLightColor(status.collect.color)
            back()
        end
    end
end
 
function checkFreeSpace()
    if d.count(d.inventorySize()) >= 1 then
        home()
        back()
    end
end
 
function collect()
    slow(.5)
    if d.detect(0) then
        if mode == "SWING" then
            d.swing(0)
        else
            d.use(0)
        end
    end

    if place then
        d.place(0)
    end
    checkFreeSpace()
    checkEnergy()
end
 
function main()
    d.setStatusText(status.collect.text)
    d.setLightColor(status.collect.color)

    x, z, farm = 1, 1, 1
    start()

    while true do
        if x == 1 and z == sizeZ or x == sizeX and z == sizeZ then
            home()
            break
        elseif x == sizeX or x == 1 and z > 1 then
            z = z + 1
            move(0, 0, 1)
            collect()
        end
        if z % 2 == 1 then
            move(1, 0, 0)
            x = x + 1
        else
            move(-1, 0, 0)
            x = x - 1
        end

        collect()
    end

    d.setStatusText(status.idle.text)
    d.setLightColor(status.idle.color)
end
 
while true do
    main()
    sleep(wait)
end
