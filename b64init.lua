print("running b64init.lua")
print("heap:", node.heap())
gpio.mode(1, gpio.INPUT, gpio.PULLUP)
if gpio.read(1) == 1 then
   print("about to launch b64test.lua")
   dofile("b64test.lua")
else
   print("stopped launch, gpio low")
end


