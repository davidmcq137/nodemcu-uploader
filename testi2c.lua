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

   -- dev_addr is i2c address (e.g. 0x48), aN is analog input: 0 for A0, 1 for A1 etc
   -- returns voltage read on aN
   -- assumes we will want use single-ended conversions
   -- assumes we will want default full scale (2.048V)
   -- tmr.delay() inserted to stop nodemcu from crashing...

   local id = 0
   local ww, ack
   local ap_reg_config=0x01
   local ap_reg_conversion=0x00
   local inputCode={0xc5, 0xd5, 0xe5, 0xf5}


   -- first, set configuration, then initiate conversion
   -- see TI datasheet for bit functions
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   if not ack then print("noACK1") return nil end
   ww=i2c.write(id, ap_reg_config)
   if ww ~= 1 then print("bad write ap_reg_conf", ww) return nil end
   ww=i2c.write(id, inputCode[aN+1]) -- conversion bit + 3 bits of mux addr
   if ww ~= 1 then print("bad write input code", ww) return nil end
   ww=i2c.write(id, 0x83) -- just defaults plus single conversion
   if ww ~= 1 then print("bad write 0x83", ww) return nil end
   i2c.stop(id)
   tmr.delay(10)
   
   -- now spin on the conversion done pin
   -- usually just once thru the loop does it
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.RECEIVER)
   if not ack then print("NoACK2") return nil end
   rr=0
   for i=1,100,1 do -- really should just test high-order bit...
      rr = string.byte(i2c.read(id,2), 1)
      if rr == 255 then break end
   end
   i2c.stop(id)
   if rr ~= 255 then print("ADC Timeout") return nil end
   tmr.delay(10)

   -- now set up to read the conversion register
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   if not ack then print("NoACK3") return nil end
   ww= i2c.write(id, ap_reg_conversion)
   i2c.stop(id)
   if ww ~= 1 then print("bad write ap_reg_conv", ww) return nil end
   tmr.delay(10)
   
   -- and finally read the two bytes of result and return converted to proper units
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.RECEIVER)
   if not ack then print("NoACK4") return nil end
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

-- testing code follows

local ii=0
local v0,v1,v2,v3
local t0, t1


-- hit h/w reset to stop (!)
while true do
   ii = ii + 1

   t0 = tmr.now()

   v0 = readAdc(0x48, 0)
   if not v0 then print("error0") end
   v1 = readAdc(0x48, 0)
   if not v1 then print("error1") end
   v2 = readAdc(0x48, 0)
   if not v2 then print("error2") end
   v3 = readAdc(0x48, 0)
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
