print("initmn.lua")
local flowResetPin=2
gpio.mode(flowResetPin, gpio.INPUT, gpio.PULLUP)
local rst = gpio.read(flowResetPin)
print("reset pin 2 (GPIO4): ", rst)
if rst == 1 then dofile("mn.lua") end

