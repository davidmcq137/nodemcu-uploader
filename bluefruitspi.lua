-- The MIT License (MIT)
--
-- Copyright (c) 2018 Kevin Townsend for Adafruit_Industries
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- Ported to lua/nodemcu and un-OO-ified (sorry!) by Dave McQueeney.
-- Same MIT license terms apply
--
----------------------------------------------------------------------------
--  Original:
--- Helper class to work with the Adafruit Bluefruit LE SPI friend breakout.
--- * Author(s): Kevin Townsend
--- Implementation Notes
----------------------------------------------------------------------------
---  ** Hardware: **
--- "* `Adafruit Bluefruit LE SPI Friend <https://www.adafruit.com/product/2633>`_"

_MSG_COMMAND   = 0x10  -- Command message
_MSG_RESPONSE  = 0x20  -- Response message
_MSG_ALERT     = 0x40  -- Alert message
_MSG_ERROR     = 0x80  -- Error message
_MSG_LATER     = 0xFE  -- Try later, I'm doing the dishes
_MSG_NOCONTENT = 0xFF  -- Read request but nothing in buffer

_SDEP_INITIALIZE = 0xBEEF -- Resets the Bluefruit device
_SDEP_ATCOMMAND  = 0x0A00 -- AT command wrapper
_SDEP_BLEUART_TX = 0x0A01 -- BLE UART transmit data
_SDEP_BLEUART_RX = 0x0A02 -- BLE UART read data
_SDEP_MOSI_FILL  = 0x00AA -- Fill character for spi reads
_SDEP_BUFFER_LENGTH = 20  -- 20 chars is BLE spec
_SDEP_HEADER_LENGTH = 4   -- see SDEP docs for header defn

_ERROR_INVALIDMSGTYPE = 0x8021 -- SDEP: Unexpected SDEP MsgType
_ERROR_INVALIDCMDID   = 0x8022 -- SDEP: Unknown command ID
_ERROR_INVALIDPAYLOAD = 0x8023 -- SDEP: Payload problem
_ERROR_INVALIDLEN     = 0x8024 -- SDEP: Indicated len too large
_ERROR_INVALIDINPUT   = 0x8060 -- AT: Invalid data
_ERROR_UNKNOWNCMD     = 0x8061 -- AT: Unknown command name
_ERROR_INVALIDPARAM   = 0x8062 -- AT: Invalid param value
_ERROR_UNSUPPORTED    = 0x8063 -- AT: Unsupported command

_HSPI = 1 -- this is the "user" spi bus on the nodemcu

-- Globals for this file (upvalues) passed in with spi_init

local g_irq = 0
local g_cs = 0
local g_reset = 0

function readIRQ()
   if gpio.read(g_irq) == 1 then return false else return true end
end

function spi_init (id, cs, irq, reset)
   
   -- See nodemcu docs for more inf on spi, struct, and gpio
   -- modules that are relied upon in this lua/nodemcu port
   -- See for example https://nodemcu.readthedocs.io/en/master/en/modules/spi/
   --
   -- id must be _HSPI (the user spi bus on nodemcu .. _HSPI = 1)
   -- cs  defaults to I/O index 8, GPIO 15
   -- clk  must be on I/O index 5, GPIO 14
   -- mosi must be on I/O index 7, GPIO 13
   -- miso must be on I/O index 6, GPIO 12
   -- reset is a hw pin on the BLE SPI Friend
   -- irq/dataready is a hw pin on the BLE SPI Friend
   --
   -- We observed the BLE SPI module to work at 4MHz as claimed by Adafruit. We also
   -- tested some of the time delays in Kevin's code to see which were critical. These
   -- are noted in the comments. We observed that the pre-selected cs pin (8)
   -- used by nodemcu's spi module does not permit adequate setup time for the
   -- BLE module so we had to add a "manual" mode to make it work. See below.
   -- We also observed some odd behaviors of the "interrupt" pin called irq,
   -- for example it goes away in the middle of a multi-packet read so you can't
   -- have it gate the while loop (see the code in spi_command)
   --
   -- I changed the calling convention .. no need to add \n explicitly to AT commands
   -- low level rountine (spi_cmd) will add it if needed
   --
   -- Reset is active low. Can do via this hw pin or via sw (spi_SDEP_init)
   if reset ~= 0 then
      print("RESETTING BLE FRIEND")
      gpio.mode(reset, gpio.OUTPUT, gpio.PULLUP)
      gpio.write(reset, gpio.LOW)
      tmr.delay(500000)
      gpio.write(reset, gpio.HIGH)
      g_reset =reset
      tmr.delay(500000)
   end
   
   --CS is an active low output, defaults to gpio 8
   if cs ~= 8 then
      gpio.mode(cs, gpio.OUTPUT)
      gpio.write(cs, gpio.HIGH)
      g_cs = cs -- g_cs ~= 0 if in "manual cs" mode
   end

   gpio.mode(irq, gpio.INPUT)    -- no option for pulldown in esp8266
   g_irq = irq
   
   local DATABITS = 8
   local CLOCKDIV = 20 -- divides 80MHz by this to get act rate -- 20 sets to 4MHz

   kk = spi.setup(_HSPI, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW,DATABITS, CLOCKDIV)
   return kk
end


function spi_cmd(SDEP_func, cmdP)
   
   --parameter SDEP_func can be _SDEP_ATCOMMAND for execution of AT commands
   --or _SDRP_BLEUART_TX or .._RX for UART functions
   --Executes the supplied AT command, which may be terminated with a new-line character
   --Returns msgtype, rspid, rsp, which are 8-bit int, 16-bit int and a bytearray
   --parameter cmdP: AT command to execute, or UART input or output
   --return string will be "OK\r\n" terminated for AT commands

   local buf_tx
   local cmd

   if SDEP_func ~= _SDEP_ATCOMMAND and SDEP_func ~= _SDEP_BLEUART_TX and
                    SDEP_func ~= _SDEP_BLEUART_RX and SDEP_func ~= _SDEP_INITIALIZE then
      print("ERROR: no such _SDEP command type", SDEP_func)
      return 0,0,nil
   end
   
   cmd = cmdP
   if not cmd then cmd='' end -- so that #cmd works -- cannot # a nil value      

   if #cmd > 127 then -- shouldn't this be 255?
      print("ERROR: Command too long.")
      return 0,0,nil
   end

   if SDEP_func == _SDEP_ATCOMMAND and string.byte(cmdP,-1) ~= string.byte("\n") then
      cmd = cmdP .. "\n"
   end
   
   -- for SDEP protocol see Kevin Townsend's docs: https://
   -- learn.adafruit.com/introducing-the-adafruit-bluefruit-spi-breakout/sdep-spi-data-transport
   -- this is a lua/nodemcu port from Kevin's (more elegant!) python implementation:
   -- https://
   -- github.com/adafruit/Adafruit_CircuitPython_BluefruitSPI/blob/master/adafruit_bluefruitspi.py
   
   local more = 0x80 -- More bit is in pos 8, 1 = more data available
   local pos = 0     
   local plen
   local firstpass=true

   while #cmd - pos > 0 or firstpass do

      firstpass=false -- if no payload, make sure we do this loop once to send header
      
      if #cmd - pos <= 16 then  -- Construct the SDEP packet
	 more = 0               -- more = 0 for last or sole packet
      end
      
      plen = #cmd - pos
      if plen > 16 then
	 plen = 16
      end

      --print("#cmd, plen, pos:", #cmd, plen, pos)
      
      -- do little endian pack of the message header parameters
      
      buf_tx = struct.pack("<BHB", _MSG_COMMAND, SDEP_func, plen+more)

      -- add the payload. use a table so that spi.send know how many elements to send
      -- no way to do that with a string buffer since all chars are legal data
      -- all because there is no count parameter on the spi.send on nodemcu
      
      local tx={}          -- table to act as send buffer
      for i = 1, _SDEP_HEADER_LENGTH, 1 do       -- insert params first
	 tx[i] = string.byte(buf_tx,i)
	 --print("#", i, tx[i])
      end

      if #cmd > 0 then -- no payload for BLE UART Rx
	 for i = _SDEP_HEADER_LENGTH + 1, _SDEP_HEADER_LENGTH + plen, 1 do -- then payload
	    tx[i] = string.byte(string.sub(cmd, pos+1, pos+1+plen), i - _SDEP_HEADER_LENGTH)
	    --print("@", i, tx[i])
	 end
      end
      
      --for i=1, _SDEP_HEADER_LENGTH + plen, 1 do
	-- print(string.format("-->%d 0x%02x %s", i, tx[i], string.char(tx[i]) ) )
      --end

      if g_cs ~= 0 then
	 gpio.write(g_cs, gpio.LOW)
	 tmr.delay(100)
      end
      --
      spi.send(_HSPI, tx) 
      --
      if g_cs ~= 0 then
	 tmr.delay(100)
	 gpio.write(g_cs, gpio.HIGH)
      end
      pos = pos + plen
      --print("bott pos=pos+plen: pos, plen", pos, plen)
      
   end

   -- Wait for a response (usually not even one trip thru the loop...)
   timeout = 800 -- 800 * 50 usec = 40 msec
   while timeout > 0 and not readIRQ() do
      tmr.delay(50)
      timeout = timeout - 1
   end
   
   if timeout <= 0 then
      print("ERROR: Timed out waiting for a response.")
      return 0, 0, nil
   end
   
   -- Retrieve the response message

   local msgtype = 0
   local rspid = 0
   local rsplen = 0
   local rsp = ""
   
   local ll=0
   local rx={}
   local MSG_resp=false
   local mr
   
   while readIRQ() or MSG_resp do -- use or with MSG_resp because IRQ seen to disappear sometimes
      tmr.delay(10000)            -- this tmr() is critical. works at 8000 fails at 5000. go figure.
      ll=ll+1
      -- Read the current response packet

      if g_cs ~= 0 then
	 gpio.write(g_cs, gpio.LOW)
	 tmr.delay(100)
      end
      --
      local buf_rx = spi.recv(_HSPI, _SDEP_BUFFER_LENGTH, _SDEP_MOSI_FILL)
      --
      if g_cs ~= 0 then
	 tmr.delay(100)
	 gpio.write(g_cs, gpio.HIGH)
      end
      
      if ll == 1 then -- check on very first read for response code or error
	 mr=string.byte(buf_rx, 1)
	 
	 if mr == _MSG_RESPONSE then
	    MSG_resp = true
	 else
	    print("Error response from BLE:", string.format("0x%02x", mr))
	    local ss="raw rx: "
	    local sb
	    for i=1,20,1 do
	       sb = string.byte(buf_rx, i)
	       ss=ss..string.format("%d 0x%02x %s", i, sb, string.char(sb))
	    end
	    print(ss)
	    return 0,0,nil
	 end
      end
      
      -- Read the message envelope and contents -- note < vs > on Kevin's code
      msgtype, rspid, rsplen = struct.unpack('<BHB', buf_rx)

      --print(string.format("%%msgtype: 0x%02x, rspid: 0x%02x, rsplen: 0x%02x", msgtype, rspid, rsplen))
      
      if rsplen >= _SDEP_BUFFER_LENGTH - _SDEP_HEADER_LENGTH then -- more (0x80) set
	 rsp = rsp .. string.sub(buf_rx, _SDEP_HEADER_LENGTH+1, _SDEP_BUFFER_LENGTH)
	 if rsplen == _SDEP_BUFFER_LENGTH - _SDEP_HEADER_LENGTH then break end -- exact fit last one
      else
	 rsp = rsp .. string.sub(buf_rx, _SDEP_HEADER_LENGTH+1, rsplen+_SDEP_HEADER_LENGTH)
	 break -- this is the "normal" break when done with the reading as planned
      end
      if ll > 100 then print("ERROR: overrun!") break end -- just in case...
      --tmr.delay(100) -- was 10000 .. seems to run fine without it -- only top one critical
      tmr.delay(1000)
   end

   --print("bott of loop rsp:\r\n")
   --print(rsp)
   --print("\r\n")
   --print("#rsp:", #rsp)

   --for i=1,#rsp,1 do
   --   local rb = string.byte(rsp, i)
   --   print(string.format(">>%d 0x%02x '%s'", i, rb, string.char(rb)))
   --end
   
--   print("\r\n")

   return msgtype, rspid, rsp

end


function spi_SDEP_init(callBack)

   -- Sends the SDEP initialize command, which causes the board to reset.
   -- This command should complete in under 1s.

   local mt, id, rsp
   mt, id, rsp = spi_cmd(_SDEP_INITIALIZE)
   
   -- since it may take 1s to reset, allow for a pass-in callback after 1 sec
   if callBack then tmr.create():alarm(1000, tmr.ALARM_SINGLE, callBack) end

   return rsp
end

function spi_connected()
   --Checks whether the Bluefruit module is connected to the central--
   return tonumber(spi_command_check_OK('AT+GAPGETCONN\n')) == 1
end

function spi_uart_tx(data)
   --Sends the specific bytestring out over BLE UART.
   --works but prob better to use _SDEP_BLEUART_TX command instead
   return spi_command('AT+BLEUARTTX='..data)
end

function spi_uart_rx()
   --Reads byte data from the BLE UART FIFO
   --seems not to work .. prob mean to use the _SDEP_BLEUART_RX command instead
   data = spi_command_check_OK('AT+BLEUARTRX')
   if data and #data > 0 then
      return data
   else
      return nil
   end
end

function spi_command(string)
   --Send a command and check response code
   local msgtype, msgid, rsp
   msgtype, msgid, rsp = spi_cmd(_SDEP_ATCOMMAND, string)
   if not rsp or msgtype==0 or msgtype == _MSG_ERROR then
      print("_MSG_ERROR", string.format("0x%02x", msgid))
      return nil
   end
   if msgtype == _MSG_RESPONSE then
      return rsp
   else
      print("Unknown response or AT command failure", string.format("Type: 0x%02x", msgtype),
	    string.format("ID: 0x%02x", msgid))
      return nil
   end
end


function spi_command_check_OK(command, dly)

   --Send a fully formed bytestring AT command, and check
   --whether we got an 'OK' back. Returns payload bytes if there are any
   --why on earth would we want dly? make it optional...
   --returns string with OK\r\n stripped out if it worked, nil if error

   ret = spi_command(command)
   --print("spi_cc_OK - ret from spi_cmd: ")
   --print(ret)

   if dly then tmr.delay(dly) end -- note dly is usec, not msec

   if  ret == nil or #ret == 0 or #string.sub(ret,1, -5) == 0 then
      print("cc - No return data")
      return nil
   end
   
   if string.sub(ret,-4) ~= 'OK\r\n' then
      print("cc - No OK returned")
      return nil
   end
   -- return is 0\r\nOK\r\n or 1\r\nOK\r\n
   -- remove the OK\r\n and return the rest
   if #string.sub(ret, 1, -5) ~= 0 then
      return string.sub(ret, 1, -5)
   end
   
   return nil
end


--function spi_init (spi, cs, irq, reset)

spi_init (_HSPI, 1, 2, 0) -- alt cs is 1

print("1. spi_cmd(_SDEP_ATCOMMAND, 'AT+BLEGETADDR')")
local msgtype, rspid, rsp
msgtype, rspid, rsp = spi_cmd(_SDEP_ATCOMMAND, "AT+BLEGETADDR")
print("msgtype, rspid, rsp:",
      string.format("0x%02x", msgtype),
      string.format("0x%02x", rspid) )

if not rsp then print("bye") return end


print("#rsp:", #rsp)
print("rsp:")
print(rsp)

local ss="rsp: "
for i=1,#rsp,1 do
   local rb = string.byte(rsp, i)
   ss = ss .. string.format("0x%02x", rb)
end
print(ss)
print(" ")

print("2. spi_command_check_OK('ATI')")
rsp=spi_command_check_OK("ATI")
print("#rsp:", #rsp)
print("rsp:")
print(rsp)
print(" ")
local ss="rsp: "
for i=1,#rsp,1 do
   local rb = string.byte(rsp, i)
   ss = ss .. string.format("0x%02x", rb)
end
print(ss)
print(" ")

print("3. spi_connected()")
if spi_connected() then print("connected") else print("not connected") end
print(" ")

print("4. spi_command(str)")
str = spi_command("ATI")
print("ret:")
print(str)
print(" ")

--print("5. spi_command('AT+BLEUARTRX')")
--str = spi_command("AT+BLEUARTRX")
--print("ret:")
--print(str)
--print(" ")

print("6. spi_command_check_OK('AT+BLEGETRSSI')")
str= spi_command_check_OK("AT+BLEGETRSSI")
print("ret:")
print(str)
print(" ")

print("7. spi_command_check_OK('AT+HWRANDOM')")
str= spi_command_check_OK("AT+HWRANDOM")
print("ret:")
print(str)
print(" ")

print("8. spi_command_check_OK('AT+BLEGETADDR')")
str= spi_command_check_OK("AT+BLEGETADDR")
print("ret:")
print(str)
print(" ")

--print("9. spi_uart_tx(data)")
--ret = spi_uart_tx("Hello Apple$%&\\r\\n")
--print("ret:")
--print(ret)
--print(" ")

--print("10. spi_uart_tx(data)")
--ret = spi_uart_tx("Hello Apple Again@#$!!\\r\\n")
--print("ret:")
--print(ret)
--print(" ")

--print("11a. spi_command(AT+BLEUARTFLOW)")
--ret = spi_command("AT+BLEUARTFLOW")
--print("ret:")
--print(ret)
--print(" ")

--print("11b. spi_command(AT+BLEUARTFLOW=off)")
--ret = spi_command("AT+BLEUARTFLOW=off")
--print("ret:")
--print(ret)
--print(" ")

--print("11c. spi_command(AT+BLEUARTFLOW)")
--ret = spi_command("AT+BLEUARTFLOW")
--print("ret:")
--print(ret)
--print(" ")

--print("11c. spi_command(AT+BLEUARTFIFO=TX)")
--ret = spi_command("AT+BLEUARTFIFO")
--print("ret:")
--print(ret)
--print(" ")

--print("12. spi_uart_rx()")
--ret = spi_uart_rx()
--print("ret:")
--print(ret)
--print(" ")

local msgtype, rspid, rsp

print("13. spi_cmd(_SDEP_BLEUART_TX, '----')")
msgtype, rspid, rsp = spi_cmd(_SDEP_BLEUART_TX, "Hello There ios\\r\\n")
print("msgtype, rspid:", msgtype, rspid)
print("rsp:")
print(rsp)
print(" ")

print("14. spi_cmd(_SDEP_BLEUART_RX)")
msgtype, rspid, rsp=spi_cmd(_SDEP_BLEUART_RX)
print("msgtype, rspid:", msgtype, rspid)
print("rsp:")
print(rsp)
print(" ")

for i=1,100,1 do
   msgtype, rspid, rsp = spi_cmd(_SDEP_BLEUART_TX, "Hello There ios\\r\\n")
end









