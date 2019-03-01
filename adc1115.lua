local function b2i(b1,b2)
   local n=b1*256 + b2
   if n >= 32768 then return n-65536 else return n end
end

local lastMux=-1

function readAdc(dev_addr, aN)
   -- if mux has not changed since last read, we can read once
   -- read again if we had to change it .. can't get stable
   -- reading on the same transaction that changes the mux
   vv = readAdcI(dev_addr, aN)
   if lastMux ~= aN then
      vv = readAdcI(dev_addr, aN)
   end
   lastMux=aN
   return vv
end

function readAdcI(dev_addr, aN)

   -- works for TI ads1115 and ads1015 a/d converts with 4-input mux
   -- dev_addr is i2c address (e.g. 0x48)
   -- aN is analog input: 0 for A0, 1 for A1 etc
   -- fcn returns voltage read on mux input specified by aN
   -- assumes we will use single-ended conversions only
   -- assumes we will want default full scale (2.048V) only
   -- tmr.delay()s inserted to stop nodemcu from crashing...go figure
   -- overall per conversion for ads1115 (16 bits): 10ms
   -- overall per conversion for ads1015 (12 bits): 0.8 ms
   -- in both cases this is if correct mux already selected, 2x otherwise
   
   local id = 0
   local ww, ack
   local ap_reg_config=0x01
   local ap_reg_conversion=0x00
   local inputCode={0xc5, 0xd5, 0xe5, 0xf5}


   -- first, set configuration, then initiate conversion
   -- see TI datasheet for bit functions
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   if not ack then print("No ACK from adc on address") return nil end
   ww=i2c.write(id, ap_reg_config)
   ww=i2c.write(id, inputCode[aN+1]) -- conversion bit + 3 bits of mux addr
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
   if rr ~= 255 then print("adc timeout") return nil end
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
   
   return (2.048 * b2i(string.byte(c,1), string.byte(c,2)) / 32767) 

end

-- initialize i2c, set pin1 as sda, set pin2 as scl
local id = 0
local sda = 1
local scl = 2

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

   v0 = readAdc(0x48, 0)
   if not v0 then print("error0") end
   v1 = readAdc(0x48, 1)
   if not v1 then print("error1") end
   v2 = readAdc(0x48, 2)
   if not v2 then print("error2") end
   v3 = readAdc(0x48, 3)
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

