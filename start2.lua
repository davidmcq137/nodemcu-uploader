--start2.lua
print("running start2.lua")
print("heap:", node.heap())
gpio.mode(3, gpio.INPUT)
if gpio.read(3) == 1 then LFS.medidoSPISUI() end

