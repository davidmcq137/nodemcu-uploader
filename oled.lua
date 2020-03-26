local dispRstPin        = 0 --GPIO 16

local dw=128
local dh=64

function cdisp(font, text, x, y)
   local ww, xd
   if not font then
      print("no font")
      return
   end
   if not text then
      print("no text")
      return
   end
   disp:setFont(font)
   ww=disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   disp:drawStr(xd, y, text)
end

function init_i2c_display()

   gpio.write(dispRstPin, 1)
   gpio.write(dispRstPin, 0)
   tmr.delay(200)
   gpio.write(dispRstPin, 1)
   

   -- we assume i2c.setup already called
   local sla = 0x3c
   disp = u8g2.ssd1306_i2c_128x64_noname(0, sla)
   disp:setFontRefHeightExtendedText()
   disp:setDrawColor(1)
   disp:setFontPosTop()
   disp:setFontDirection(0)
end

local textLCD = {}

function timeFmt(tt)
   local irt = math.floor(tt)
   if tt < 60 then
      tstr = string.format("Tim %d sec", tt)
   else
      local min = math.floor(irt/60)
      local sec = math.floor(irt-60*min)
      tstr = string.format("Tim %2d:%02d min",  min, sec)
   end
   return tstr
end

function lineLCD(line, txt, val, fmt, sfx)
   if not line then
      for i = 1, 4, 1 do
	 textLCD[i]=nil
      end
      return
   end
   if not val then
      textLCD[line] = txt
   else
      textLCD[line] = txt .. " " .. string.format(fmt, val) .. sfx
   end
end

function showLCD()
   local io = 2
   if not disp then return end
   disp:clearBuffer()
   for i = 1, 4, 1 do
      if textLCD[i] then
	 cdisp(u8g2.font_profont17_mr, textLCD[i], 1,  (i-1)*15+io)
      end
   end
   disp:sendBuffer()
end



print("starting .. reset disp")

-- first do a clean reset of the display driver

gpio.mode(dispRstPin, gpio.OUTPUT)
gpio.write(dispRstPin, 1)

-- Initialize the i2c bus

local sda, scl = 4, 3

print("about to i2csetup")
i2c.setup(0, sda, scl, i2c.SLOW)


init_i2c_display()
--disp:setPowerSave(0)
disp:clearBuffer()

--  U8G2_FONT_TABLE_ENTRY(font_6x10_tf) \
--  U8G2_FONT_TABLE_ENTRY(font_helvB12_tf) \
--  U8G2_FONT_TABLE_ENTRY(font_profont17_mr) \
--  U8G2_FONT_TABLE_ENTRY(font_profont22_mr) \
--  U8G2_FONT_TABLE_ENTRY(font_inb16_mr)	 \
--  U8G2_FONT_TABLE_ENTRY(font_inb24_mr) 

io=2
--cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
--cdisp(u8g2.font_profont17_mr, "BLE v1.0", 0, 20+io)

cdisp(u8g2.font_helvB12_tf, "MedidoPump", 0, 0+io)
cdisp(u8g2.font_helvB12_tf, "BLE v1.0", 0, 15+io)
cdisp(u8g2.font_helvB12_tf, "UART P", 0, 30+io)
cdisp(u8g2.font_helvB12_tf, "Test123", 0, 45+io)

disp:sendBuffer()

print("done")
