-- Set up the gpio interrupt to catch pulses from the flowmeter

local flowMeterPin = 8 --GPIO15
local pulseCount = 0
local flowCount = 0
local pumpFwd = true
local pulsePerOz = 111.0

function gpioCB(lev, pul, cnt)
   if pumpFwd then
      pulseCount=pulseCount + cnt
   else
      pulseCount=pulseCount - cnt
   end
   flowCount = pulseCount / pulsePerOz
   print("Flow (oz):", flowCount)
   gpio.trig(flowMeterPin, "up")
end

print("Starting up, enabling flowmeter")

gpio.mode(flowMeterPin, gpio.INT)
gpio.trig(flowMeterPin, "up", gpioCB)

