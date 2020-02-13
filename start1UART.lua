--start1UART.lua
print("running start1UART.lua")
print("heap:", node.heap())
gpio.mode(1, gpio.INPUT, gpio.PULLUP)
if gpio.read(1) == 1 then LFS.medidoUART() end

