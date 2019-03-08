--[[

mcp23008.lua

drive the i2c gpio extender chip
so far only implemented/tested for all bits as output

set up as a lua module so you can do:

mcp = require "mcp23008"

two external function calls:

mcp23008.gpioSetIOdir() -- call after setup to config outputs (see test code below)
mcp23008.gpioWritePin() -- call to set a gpio pin to 1 or 0 

--]]

local mcp23008 = {}

local outbits = {0,0,0,0,0,0,0,0} -- store bit values here
local outmult = {1,2,4,8,16,32,64,128}
local dev_addr  = 0x20
local reg_iodir = 0x00 -- various chip registers - see data sheet
local reg_gpio  = 0x09
local reg_olat  = 0x0a

function mcp23008.gpioWritePin(bitpos, value)

   if value ~= 0 then outbits[bitpos] = 1 else outbits[bitpos] = 0 end
   
   local outword = 0
   for i=1,8,1 do
      outword = outword + outbits[i] * outmult[i]
   end
   
   --if outword ~= 0 then print(string.format("0x%02x", outword)) end
   
   gpioWriteAll(outword)

end

function gpioWriteAll(aN)

   local id = 0
   local ww, ack
   
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   if not ack then
      print("No ACK from device on gpioWriteAll")
      return nil
   end
   
   ww=i2c.write(id, reg_gpio)
   ww=i2c.write(id, aN)
   i2c.stop(id)
   tmr.delay(10)

end

function mcp23008.gpioSetIOdir(aN)

   local id = 0
   local ww, ack
   
   i2c.start(id)
   ack=i2c.address(id, dev_addr, i2c.TRANSMITTER)
   if not ack then
      print("No ACK from device on gpioSetIOdir")
      return nil
   end
   
   ww=i2c.write(id, reg_iodir)
   ww=i2c.write(id, aN) -- see datasheet: 0 bit for write, 1 bit for read
   i2c.stop(id)
   tmr.delay(10)
   
end

--[[

Test Code

-- initialize i2c, set pin1 as sda, set pin2 as scl

local id = 0
local sda = 4 -- GPIO 2
local scl = 3 -- GPIO 0


-- note sda and scl are labelled wrong on the silkscreen of the Huzzah board (!)
i2c.setup(id, sda, scl, i2c.SLOW)
gpioSetIOdir(0x00) -- set for all outputs
   
while true do
   gpioWritePin(2, 1)
   tmr.delay(10)
   gpioWritePin(2, 0)
end

--]]

return mcp23008
