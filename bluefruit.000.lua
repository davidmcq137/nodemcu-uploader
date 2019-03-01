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
--
----------------------------------------------------------------------------
--- Helper class to work with the Adafruit Bluefruit LE SPI friend breakout.
--- * Author(s): Kevin Townsend
--- Implementation Notes
----------------------------------------------------------------------------
--- **Hardware:**
--- "* `Adafruit Bluefruit LE SPI Friend <https://www.adafruit.com/product/2633>`_"

_MSG_COMMAND   = 0x10  -- Command message
_MSG_RESPONSE  = 0x20  -- Response message
_MSG_ALERT     = 0x40  -- Alert message
_MSG_ERROR     = 0x80  -- Error message

_SDEP_INITIALIZE = 0xBEEF -- Resets the Bluefruit device
_SDEP_ATCOMMAND  = 0x0A00 -- AT command wrapper
_SDEP_BLEUART_TX = 0x0A01 -- BLE UART transmit data
_SDEP_BLEUART_RX = 0x0A02 -- BLE UART read data

_ARG_STRING    = 0x0100 -- String data type
_ARG_BYTEARRAY = 0x0200 -- Byte array data type
_ARG_INT32     = 0x0300 -- Signed 32-bit integer data type
_ARG_UINT32    = 0x0400 -- Unsigned 32-bit integer data type
_ARG_INT16     = 0x0500 -- Signed 16-bit integer data type
_ARG_UINT16    = 0x0600 -- Unsigned 16-bit integer data type
_ARG_INT8      = 0x0700 -- Signed 8-bit integer data type
_ARG_UINT8     = 0x0800 -- Unsigned 8-bit integer data type

_ERROR_INVALIDMSGTYPE = 0x8021 -- SDEP: Unexpected SDEP MsgType
_ERROR_INVALIDCMDID   = 0x8022 -- SDEP: Unknown command ID
_ERROR_INVALIDPAYLOAD = 0x8023 -- SDEP: Payload problem
_ERROR_INVALIDLEN     = 0x8024 -- SDEP: Indicated len too large
_ERROR_INVALIDINPUT   = 0x8060 -- AT: Invalid data
_ERROR_UNKNOWNCMD     = 0x8061 -- AT: Unknown command name
_ERROR_INVALIDPARAM   = 0x8062 -- AT: Invalid param value
_ERROR_UNSUPPORTED    = 0x8063 -- AT: Unsupported command

-- For the Bluefruit Connect packets
_PACKET_BUTTON_LEN    = 5
_PACKET_COLOR_LEN     = 6

byterev = {
  0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,  
  0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,  
  0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,  
  0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,  
  0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,  
  0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA, 
  0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,  
  0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE, 
  0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1, 
  0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,  
  0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5, 
  0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD, 
  0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,  
  0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB, 
  0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,  
  0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF 
}; 


local buffer, buf_tx, buf_rx

g_irq = 0
g_cs = 0
g_reset = 0

function readIRQ()
   if gpio.read(g_irq) == 1 then return false else return true end
end

function spi_init (id, cs, irq, reset, debugON)

   if reset ~= 0 then
      print("spi_init: resetting")
      gpio.mode(reset, gpio.OUTPUT, gpio.PULLUP)
      gpio.write(reset, gpio.LOW)
      tmr.delay(500000)
      gpio.write(reset, gpio.HIGH)
      g_reset =reset
      tmr.delay(500000)
      print("spi_init: done resetting")
   end
   
   --CS is an active low output, defaults to gpio 8
   if cs ~= 8 then
      print("spi_init: setting up cs")
      gpio.mode(cs, gpio.OUTPUT)
      gpio.write(cs, gpio.HIGH)
      g_cs = cs
   end
   

   print("spi_init: setting up irq")
   gpio.mode(irq, gpio.INPUT)    -- no option for pulldown in esp8266
   g_irq = irq
   
   local DATABITS = 8
   local CLOCKDIV = 20 -- divides 80MHz by this to get act rate -- 80 sets to 1MHz

   print("spi_init: calling setup")
   kk = spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW,DATABITS, CLOCKDIV, spi.FULLDUPLEX)

   return kk

   
end


function spi_cmd(cmd)

   --Executes the supplied AT command, which must be terminated with a new-line character
   --Returns msgtype, rspid, rsp, which are 8-bit int, 16-bit int and a bytearray
   --parameter cmd: The new-line terminated AT command to execute.

   debugOn=true
   
   -- Make sure we stay within the 255 byte limit
   if #cmd > 127 then
      if debugOn then
	 print("ERROR: Command too long.")
      end
   end
   
   more = 0x80 -- More bit is in pos 8, 1 = more data available
   pos = 0
   kk1=readIRQ()
   tt1=tmr.now()
   jj=0
   while #cmd - pos > 0 do
      jj=jj+1
      -- Construct the SDEP packet
      if #cmd - pos <= 16 then
      -- Last or sole packet
	 more = 0
      end
      
      plen = #cmd - pos
      if plen > 16 then
	 plen = 16
      end

      local plm = plen + more
      print("plm:", plm)
      local ss=string.sub(cmd, pos+1, pos+1+plen)
      print("ss:", ss)
      local s16=ss..string.rep("\0",16) -- nodemcu struct does not pad w/nulls so we must
      print("s16:", s16)
      buf_tx = struct.pack("<BHBc16", _MSG_COMMAND, _SDEP_ATCOMMAND, plm, s16)
      --buf_tx = struct.pack("<BHBc16", _MSG_COMMAND, _SDEP_BLEUART_TX, plm, s16)      

      
      ss='packed buffer: '
      for i=1,4+plen,1 do
	 ss = ss .. string.format("0x%02x ", string.byte(buf_tx, i)) 
      end
      print(ss)

      local tx={}
      for i=1,4+plen,1 do
	 tx[i] = string.byte(buf_tx,i)
	 --tx[i] = byterev[1+string.byte(buf_tx, i)]
      end
      
      ss='buffer to send: '
      for i=1,4+plen,1 do
	 ss = ss .. string.format("0x%02x ", tx[i]) 
      end
      print(ss)
      
      pos = pos + plen
      if g_cs ~= 0 then
	 gpio.write(g_cs, gpio.LOW)
	 tmr.delay(100)
      end
      print("#tx:",#tx)
      
      spi.send(1, tx)
      --spi.send(1, buf_tx)
      if g_cs ~= 0 then
	 tmr.delay(100)
	 gpio.write(g_cs, gpio.HIGH)
      end
      tts=tmr.now()
   end
   
   -- Wait for a response

   timeout = 2000
   while timeout > 0 and not readIRQ() do
      tmr.delay(50)
      timeout = timeout - 1
   end
   
   if timeout <= 0 then
      if debugOn then
	 print("ERROR: Timed out waiting for a response.")
      end
   end
   --print("past timeout loop")
   
   -- Retrieve the response message

   msgtype = 0
   rspid = 0
   rsplen = 0
   rsp = ""

   kk2=readIRQ()
   tt2=tmr.now()
   tt3=0

  ss="Read: "
   ll=0
   rx={}
   firstgood=false
   while readIRQ() or firstgood do
      tmr.delay(10000)
      ll=ll+1
      -- Read the current response packet
      --tmr.delay(100)

      if g_cs ~= 0 then
	 gpio.write(g_cs, gpio.LOW)
	 tmr.delay(100)
      end

      --rx[ll] = spi.recv(1, 1, 0xAA)
      buf_rx = spi.recv(1,20,0xAA)

      if g_cs ~= 0 then
	 tmr.delay(100)
	 gpio.write(g_cs, gpio.HIGH)
      end
      
      if ll == 1 then
	 fg=string.byte(buf_rx, 1)
	 if fg == 0x20 then firstgood = true end
	 print("first bye of resp:",
	       string.format("0x%02x ", string.byte(buf_rx,1) ) )
      end
      
      -- Read the message envelope and contents
      msgtype, rspid, rsplen = struct.unpack('<BHB', buf_rx)

      print(string.format("msgtype: 0x%02x, rspid: 0x%02x, rsplen: 0x%02x", msgtype, rspid, rsplen))
      if msgtype == 0xff then break end
      
      if rsplen >= 16 then
	 rsp = rsp .. string.sub(buf_rx, 5, 20)
      else
	 rsp = rsp .. string.sub(buf_rx, 5, rsplen+3)
	 break
      end
      if ll > 200 then print("overrun!") break end
      tmr.delay(50000)
   end

   print("rsp:\r\n\n")
   print(rsp)

   print("\r\n\n")
   for i=1,#rsp,1 do
      local rb = string.byte(rsp, i)
      print(string.format("%d 0x%02x '%s'", i, rb, string.char(rb)))
   end
   
   print("\r\n\n\n")

   print("tt3-tt2:", tt3-tt2)
   print("tt2-tt1:", tt2-tt1)
   print("tts-tt1:", tts-tt1)
   print(timeout)
   print("kk1:", kk1)
   print("kk2:", kk2)
   print("jj:", jj)
   
   return msgtype, rspid, rsp
end


function SDEPinit()

   -- Sends the SDEP initialize command, which causes the board to reset.
   -- This command should complete in under 1s.
   
   -- Construct the SDEP packet
   -- #struct.pack_into("<BHB", self.buf_tx, 0,
   -- #_MSG_COMMAND, _SDEP_INITIALIZE, 0)
   buf_tx = struct.pack("<BHB", _MSG_COMMAND, _SDEP_INITIALIZE, 0)
   ss="Writing: "
   if debugOn then
      for i=1,#buf_tx,1 do
	 ss = ss .. string.format(" 0x%02x ", string.byte(buf_tx, i)) 
	 print(ss)
      end
      --#print("Writing: ", [hex(b) for b in self._buf_tx])
   end
   
   -- Send out the SPI bus
   --#with self._spi_device as spi
   --#spi.write(self._buf_tx, end=4) -- pylint: disable=no-member
   spi.send(1, buf_tx)
   
   -- Wait 1 second for the command to complete.
   
   --OY! how to handle..?
   
   --#time.sleep(1)

end

--[[
    @property
    def connected(self):
        """Whether the Bluefruit module is connected to the central"""
        return int(self.command_check_OK(b'AT+GAPGETCONN')) == 1

    def uart_tx(self, data):
        """
        Sends the specific bytestring out over BLE UART.
        :param data: The bytestring to send.
        """
        return self._cmd(b'AT+BLEUARTTX='+data+b'\r\n')

    def uart_rx(self):
        """
        Reads byte data from the BLE UART FIFO.
        """
        data = self.command_check_OK(b'AT+BLEUARTRX')
        if data:
            -- remove \r\n from ending
            return data[:-2]
        return None

    def command(self, string):
        """Send a command and check response code"""
        try:
            msgtype, msgid, rsp = self._cmd(string+"\n")
            if msgtype == _MSG_ERROR:
                raise RuntimeError("Error (id:{0})".format(hex(msgid)))
            if msgtype == _MSG_RESPONSE:
                return rsp
            else:
                raise RuntimeError("Unknown response (id:{0})".format(hex(msgid)))
        except RuntimeError as error:
            raise RuntimeError("AT command failure: " + repr(error))

    def command_check_OK(self, command, delay=0.0):   -- pylint: disable=invalid-name
        """Send a fully formed bytestring AT command, and check
        whether we got an 'OK' back. Returns payload bytes if there is any"""
        ret = self.command(command)
        time.sleep(delay)
        if not ret or not ret[-4:]:
            raise RuntimeError("Not OK")
        if ret[-4:] != b'OK\r\n':
            raise RuntimeError("Not OK")
        if ret[:-4]:
            return ret[:-4]
        return None

    def read_packet(self):   -- pylint: disable=too-many-return-statements
        """
        Will read a Bluefruit Connect packet and return it in a parsed format.
        Currently supports Button and Color packets only
        """
        data = self.uart_rx()
        if not data:
            return None
        -- convert to an array of character bytes
        self.buffer += [chr(b) for b in data]
        -- Find beginning of new packet, starts with a '!'
        while self.buffer and self.buffer[0] != '!':
            self.buffer.pop(0)
        -- we need at least 2 bytes in the buffer
        if len(self.buffer) < 2:
            return None

        -- Packet beginning found
        if self.buffer[1] == 'B':
            plen = _PACKET_BUTTON_LEN
        elif self.buffer[1] == 'C':
            plen = _PACKET_COLOR_LEN
        else:
            -- unknown packet type
            self.buffer.pop(0)
            return None

        -- split packet off of buffer cache
        packet = self.buffer[0:plen]

        self.buffer = self.buffer[plen:]    -- remove packet from buffer
        if sum([ord(x) for x in packet]) % 256 != 255: -- check sum
            return None

        -- OK packet's good!
        if packet[1] == 'B':  -- buttons have 2 int args to parse
            -- button number & True/False press
            return ('B', int(packet[2]), packet[3] == '1')
        if packet[1] == 'C':  -- colorpick has 3 int args to parse
            -- red, green and blue
            return ('C', ord(packet[2]), ord(packet[3]), ord(packet[4]))
        -- We don't nicely parse this yet
        return packet[1:-1]

--]]
--function spi_init (spi, cs, irq, reset, debugON)
spi_init (1, 1, 2, 0, true) -- alt cs is 1
spi_cmd("ATI".."\n")
