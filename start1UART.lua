--start1UART.lua
print("running start1UART.lua")
print("heap:", node.heap())
gpio.mode(1, gpio.INPUT, gpio.PULLUP)
if gpio.read(1) == 0 then LFS.medidoUART() else
   print("Aborting start, GPIO 5 is high")
end

