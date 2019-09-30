r = component.proxy(component.list("robot")())
 
size_x, size_z = 8, 8 --Размер фермы по X и Z
wait = 2500 --Ожидание (в секундах)
wait_charge = 15 --Ожидание зарядки(Если кончится заряд при СБОРЕ(в секундах))
procent_go_back = 20 --Процент заряда, при котором идёт возвращение домой
version = "swing" --Версия работы(swing - ломать(нужна культура в 1 слоте), use - собирать)

status = {
    collect = 0xe8e81e,
    wait = 0xffffff,
    charge = 0x64ea12
}
   
function sleep(timeout)
    deadline = computer.uptime() + timeout
    repeat
        computer.pullSignal(deadline - computer.uptime())
    until computer.uptime() >= deadline
end
 
function move(block, side)
    for i = 1, block do
        while not r.move(side) do end
    end 
end
 
function go_home()
    if z % 2 == 1 then
        r.turn(true)
        r.turn(true)
        move(x, 3)
        r.turn(true)
    else
        move(1, 3)
        r.turn(true)
    end
    move(z + 1, 3)
    if version == "swing" then
        start_slot = 2
    else
        start_slot = 1
    end
    for slot = start_slot, r.inventorySize() do
      r.select(slot)
      r.drop(0)
    end
    r.select(1)
    r.turn(true)
    r.turn(true)
    move(1, 3)
    r.turn(false)
    move(1, 0)
end

function go_back()
    move(1, 1)
    r.turn(true)
    move(z, 3)
    r.turn(false)
    move(x, 3)
end
 
function check_energy()
    if computer.energy() <= procent_go_back * (computer.maxEnergy() / 100) then
        go_home()
        r.setLightColor(status.charge)
        sleep(wait_charge)
        if computer.energy() <= procent_go_back * (computer.maxEnergy() / 100) then
            computer.shutdown()
        else
            r.setLightColor(status.collect)
            go_back()
        end
    end
end
 
function check_count()
    if r.count(r.inventorySize()) >= 1 then
        go_home()
        go_back()
    end
end
 
function stuff()
    if r.detect(0) then
        if version == "swing" then
            r.swing(0)
            r.place(0)
        else
            r.use(0)
        end
        check_count()
    end
    check_energy()
end
 
function farm()
    r.setLightColor(status.collect)
    x, z = 1, 1
    move(1, 1)
    r.turn(true)
    move(1, 3)
    r.turn(false)
    move(1, 3)
    stuff()
    while true do
        if x == size_x and z == size_z or x == 1 and z == size_z and z % 2 == 0 then
            go_home()
            break
        elseif x == size_x or x == 1 and z > 1 then 
            if z % 2 == 1 then
                r.turn(true)
                move(1, 3)
                r.turn(true)
            else
                r.turn(false)
                move(1, 3)
                r.turn(false)
            end
            stuff()
            z = z + 1 
        end
        if z % 2 == 1 then
            x = x + 1
        else
            x = x - 1 
        end
        move(1, 3)
        stuff()
    end
    r.setLightColor(status.wait)
end
 
while true do
    farm()
    sleep(wait)
end
