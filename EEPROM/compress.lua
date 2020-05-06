local lz77 = require("lz77")

local function compress(data)
    local compressed = lz77.compress(data, 80)
    local file = io.open("/home/minified.lua", "w")
    file:write(([=[local i=[[%s]]local j,O,I,s,l,p,f=1,"",i;while j<=#i do l,s=I:byte(j,j+1)s=s or 0l=l+(l>13 and 1 or 2)-(l>93 and 1 or 0)s=s-(s>13 and 1 or 0)-(s>93 and 1 or 0)if l>80then l=l-80O=O..I:sub(j+1,j+l)j=j+l elseif l>2 then f=#O+(s-253)while l>0 do p=O:sub(f,f+l-1)O=O..p f=f+#p l=l-#p end j=j+1 else O=O.."]"end j=j+1 end load(O,"=bios")()]=]):format(compressed))
    file:close()
end

compress(io.read())