d = component.proxy(component.list("drone")())

size_x, size_z = 10, 10 --Размер фермы по X и Z. P.S Учтите, что дрон привязан к глобальной системе координат.
wait = 300 --Ожидание (в секундах)
wait_charge = 15 --Ожидание зарядки(Если кончится заряд при СБОРЕ(в секундах))
procent_go_back = 20 --Процент заряда, при котором идёт возвращение домой
 
status = {
    collect = {"Сбор\nурожая...", 0xe8e81e},
    wait = {"Ожидание\n...", 0xffffff},
    charge = {"Зарядка...", 0x64ea12}
}
   
function sleep(timeout)
    deadline = computer.uptime() + timeout
    
    repeat
        computer.pullSignal(deadline - computer.uptime())
    until computer.uptime() >= deadline
end
 
function move(x, y, z)
    d.move(-x, y, z)

    while d.getOffset() > .5 do
        sleep(.1)
    end
end
 
function go_home()
    move(-x, 0, -z)
    move(0, 0, -2)

    while d.getOffset() > 0 do
        sleep(.5)
    end

    for i = 1, d.inventorySize() do
        d.select(i)
        d.drop(0)
    end

    d.select(1)
    move(0, -1, 1)
end
 
function go_back()
    move(0, 1, 1)
    move(x, 0, z)
end
 
function check_energy()
    if computer.energy() <= procent_go_back * (computer.maxEnergy() / 100) then
        go_home()
        d.setStatusText(status.charge[1])
        d.setLightColor(status.charge[2])
        sleep(wait_charge)
        if computer.energy() <= procent_go_back * (computer.maxEnergy() / 100) then
            d.setStatusText("Кончилась\nЭнергия")
            computer.shutdown()
        else
            d.setStatusText(status.collect[1])
            d.setLightColor(status.collect[2])
            go_back()
        end
    end
end
 
function check_count()
    if d.count(d.inventorySize()) >= 1 then
        go_home()
        go_back()
    end
end
 
function stuff()
    if d.detect(0) then
        d.use(0)
    end
    check_count()
    check_energy()
end
 
function farm()
    d.setStatusText(status.collect[1])
    d.setLightColor(status.collect[2])
    x, z = 1, 0
    move(1, 1, 1)
    stuff()

    while true do
        if x == 1 and z + 1 == size_z or x == size_x and z + 1 == size_z then
            go_home()
            break
        elseif x == size_x or x == 1 and z > 0 then
            z = z + 1
            move(0, 0, 1)
            stuff()
        end
        if z % 2 == 0 then
            move(1, 0, 0)
            x = x + 1
        else
            move(-1, 0, 0)
            x = x - 1
        end
        stuff()
    end

    d.setStatusText(status.wait[1])
    d.setLightColor(status.wait[2])
end
 
while true do
    farm()
    sleep(wait)
end
