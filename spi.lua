spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 20, spi.HALFDUPLEX)
gpio.mode(2, gpio.INPUT)

k=spi.send(1, "A","T","I", 13, 10)
print("sent", k)
rr = spi.recv(1, 2)
for i=1,2,1 do
   print(i, string.byte(rr, i))
end
