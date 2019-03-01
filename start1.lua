--start1.lua
print("runningstart1.lua")
print("heap:", node.heap())
gpio.mode(3, gpio.INPUT)
if gpio.read(3) == 1 then LFS.bluefruitspi() end

