dw=128
dh=64

function cdisp(font, text, x, y)
   local ww, xd
   disp:setFont(font)
   ww=disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   disp:drawStr(xd, y, text)
end

function init_i2c_display()

   local rst  =7 -- GPIO 13
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
   
   disp:setFontRefHeightExtendedText()
   disp:setDrawColor(1)
   disp:setFontPosTop()
   disp:setFontDirection(0)
end

init_i2c_display()

disp:clearBuffer()

u8g2_prepare()

io=2
cdisp(u8g2.font_helvB12_tf, string.format("Line 1 test %2.1f", 1.1), 0, 0+io)
cdisp(u8g2.font_helvB12_tf, string.format("Line 2 test %2.1f", 2.2), 0, 15+io)
cdisp(u8g2.font_helvB12_tf, string.format("Line 3 test %2.1f", 3.3), 0, 30+io)
cdisp(u8g2.font_helvB12_tf, "Line 4 test", 0, 45+io)

disp:sendBuffer()
