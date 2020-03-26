--start1HTTP.lua
print("running start1HTTP.lua")
print("heap:", node.heap())
gpio.mode(1, gpio.OUTPUT)
gpio.write(1, gpio.LOW)
gpio.mode(1, gpio.INPUT) --, gpio.PULLUP)

print("launch would go here")

--if gpio.read(1) == 0 then LFS.HTTP_OTA() else
--   print("Aborting start, GPIO 5 is high")
--end

