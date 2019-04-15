local DATABITS = 32
local CLOCKDIV = 20 -- divides 80MHz by this to get act rate -- 20 sets to 4MHz
local ii = 0
local kk = 0

function spiCB()
   spi3(kk)
   kk = kk + 1
   if kk > 9 then kk = 0 end
end

function spi3(ii)
   --gpio.write(8, 0)
   local iout = 0 + bit.lshift(0, 4) + bit.lshift(0, 8) + bit.lshift(0, 12) + bit.lshift(ii, 16) + bit.lshift(0, 20) + bit.lshift(0, 24) + bit.lshift(0, 28)
   
   --spi.send(1, ii+jj*16, 5+16*10, 10+16*5)
   spi.send(1, iout)
   --gpio.write(8, 1)
   --gpio.write(8, 0)   
   
   --spi.send(1, 0)
   --spi.send(1, ii + jj*256)
end


local xx = spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW,DATABITS, CLOCKDIV)

-- redefine io index 8 (CS for SPI) to only fire once per triplet of data bytes
-- vs on each byte as it would normally do

--gpio.mode(8, gpio.OUTPUT)
--gpio.write(8, 0)

print("return from spi.setup:", xx)


local spiTimer = tmr.create()

spiTimer:register(75, tmr.ALARM_AUTO, spiCB)
spiTimer:start()

