
local dw=128
local dh=64

function cdisp(font, text, x, y)
   local ww, xd
   disp:setFont(font)
   ww=disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   disp:drawStr(xd, y, text)
end

function init_i2c_display()

   local rst = 0 -- GPIO16
   local sda = 5 -- GPIO14
   local scl = 6 -- GPIO12
   local sla = 0x3c
   
   gpio.mode(rst, gpio.OUTPUT)    -- do clean reset of disp driver
   gpio.write(rst, 1)
   gpio.write(rst, 0)
   tmr.delay(200)
   gpio.write(rst, 1)
   
   i2c.setup(0, sda, scl, i2c.SLOW)
   disp = u8g2.ssd1306_i2c_128x64_noname(0, sla)
   print("disp ret:", disp)
   disp:setFontRefHeightExtendedText()
   disp:setDrawColor(1)
   disp:setFontPosTop()
   disp:setFontDirection(0)
end


print("setting up display")
init_i2c_display() -- uses (5,6) GPIO14,GPIO12 
disp:clearBuffer()
io=2
cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
cdisp(u8g2.font_profont17_mr, "Version 1.0", 0, 25+io)
print("sending disp buffer")
disp:sendBuffer()
