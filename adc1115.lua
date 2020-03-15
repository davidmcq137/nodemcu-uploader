--[[

adc1115.lua

driver for the 4-channel 16-bit TI ads1115 A/D with 4-input mux
also works with the 12-bit part, TI ads1015

set up as a lua module so you can:

ads = require "adc1115"

note: don't use "nickname" adc .. that's the internal one on the 8266

external function call:

vout = adc1115.readAdc(i2c_addr, mux_pin)

for init, see test code below
default i2c addr for the adafruit part is 0x48

--]]

local adc1115 = {}
local dev_addr = 0x48
local lastMux=-1
local lastGain=-1

function adc1115.readAdc(aN, gNp)
   -- if mux has not changed since last read, we can read once
   -- read again if we had to change it .. can't get stable
   -- reading on the same transaction that changes the mux
   -- caution: maybe same on gain?
   vv = readAdcI(aN, gNp)
   if lastMux ~= aN or lastGain ~= gNp then
      vv = readAdcI(aN, gNp)
   end
   lastMux=aN
   lastGain=gNp
   return vv
end

local function b2i(b1,b2) -- handle signed int from 2's complement
   local n=b1*256 + b2
   if n >= 32768 then return n-65536 else return n end
end

function readAdcI(aN, gNp)

   -- works for TI ads1115 and ads1015 a/d converts with 4-input mux
   -- dev_addr is i2c address (e.g. 0x48)
   -- aN is analog input: 0 for A0, 1 for A1 etc
   -- fcn returns voltage read on mux input specified by aN
   -- assumes we will use single-ended conversions only
   -- tmr.delay()s inserted to stop nodemcu from crashing...go figure
   -- overall per conversion for ads1115 (16 bits): 10ms
   -- overall per conversion for ads1015 (12 bits): 0.8 ms
   -- in both cases this is if correct mux already selected, 2x otherwise
   
   local id = 0
   local ww, ack
   local ap_reg_config=0x01
   local ap_reg_conversion=0x00
   local inputCode={0xc1, 0xd1, 0xe1, 0xf1}
   local gainCode ={0x02, 0x04, 0x06, 0x08, 0x0a}
   -- Gain: 001 is 4.096, 010 is 2.048, 011 is 1.024, 100 is 0.512, 101 is .256 +/- full scale
   local gainMult ={4.096, 2.048, 1.024, 0.512, 0.256}
   local gN
   local adcCode
   
   if gNp == nil then gN = 1 else gN = gNp end -- default is scale  +/- 2.048V 
   
   -- first, set configuration, then initiate conversion
   -- see TI datasheet for bit functions
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   if not ack then
      --print("No ACK from adc on address")
      return nil
   end
   ww=i2c.write(id, ap_reg_config)
   adcCode = bit.bor(inputCode[aN+1], gainCode[gN])
   ww=i2c.write(id, adcCode) -- conversion bit + 3 bits of mux addr + gain setting
   ww=i2c.write(id, 0x83) -- just defaults plus single conversion
   i2c.stop(id)
   tmr.delay(10)
   
   -- now spin on the conversion done bit
   -- usually just once thru the loop does it
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.RECEIVER)
   rr=0
   for i=1,10,1 do -- really should just test high-order bit...
      rr = string.byte(i2c.read(id,2), 1)
      if rr == 255 then break end
   end
   if rr ~= 255 then
      --print("adc timeout")
      return nil
   end
   i2c.stop(id)
   tmr.delay(10)

   -- now set up to read the conversion register
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   ww= i2c.write(id, ap_reg_conversion)
   i2c.stop(id)
   tmr.delay(10)
   
   -- and finally read the two bytes of result and return converted to proper units
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.RECEIVER)
   c = i2c.read(id, 2)
   i2c.stop(id)
   
   return (gainMult[gN] * b2i(string.byte(c,1), string.byte(c,2)) / 32767) 
end


--[[ 

--test code


-- initialize i2c, 
local id = 0
local sda = 4 -- GPIO2
local scl = 3 -- GPIO0

-- note sda and scl are labelled wrong on the silkscreen of the Huzzah board (!)
i2c.setup(id, sda, scl, i2c.SLOW)

--testing code follows

local ii=0
local v0,v1,v2,v3
local t0, t1


-- hit h/w reset to stop (!)
while true do
   ii = ii + 1

   t0 = tmr.now()

   v0 = readAdc(0)
   if not v0 then print("error0") end
   v1 = readAdc(1)
   if not v1 then print("error1") end
   v2 = readAdc(2)
   if not v2 then print("error2") end
   v3 = readAdc(3)
   if not v3 then print("error3") end

   t1 = tmr.now()

   print(ii,
	 string.format("%.4f", v0),
	 string.format("%.4f", v1),
	 string.format("%.4f", v2),
	 string.format("%.4f", v3),
	 t1-t0)
   --break
end

--]]

return adc1115
