function init_spi_display()
    -- Hardware SPI CLK  = GPIO14
    -- Hardware SPI MOSI = GPIO13
    -- Hardware SPI MISO = GPIO12 (not used)
    -- Hardware SPI /CS  = GPIO15 (not used)
    -- CS, D/C, and RES can be assigned freely to available GPIOs
    local cs  = 8 -- GPIO15, pull-down 10k to GND
    local dc  = 4 -- GPIO2
    local res = 0 -- GPIO16
    local bus = 1

    spi.setup(bus, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8)
    -- we won't be using the HSPI /CS line, so disable it again
    gpio.mode(8, gpio.INPUT, gpio.PULLUP)

    -- initialize the matching driver for your display
    -- see app/include/ucg_config.h
    --disp = ucg.ili9341_18x240x320_hw_spi(bus, cs, dc, res)
    disp = ucg.st7735_18x128x160_hw_spi(bus, cs, dc, res)
end



calib = 11010.8 -- measured against commercial scale
zero = -17800

function read()
   local wt = (hx711.read(0) - zero)/calib
   tmr.delay(100)
   local roundwt = (math.floor(wt*10) + 0.5)/10
   if math.abs(roundwt) < 0.2 then roundwt = 0.0 end
   local text = string.format("%4.1f lb", roundwt)
   print(wt, roundwt)

   local ww = disp:getStrWidth(text)
   local hh = disp:getFontAscent(text)
   --print("ww, hh:", ww, hh)
   disp:setPrintDir(0)

   disp:clearScreen()
   disp:setColor(255, 255, 255)
   disp:setPrintPos(dw/2 - ww/2, 10+hh)
   disp:print(text)
   

   
   movtimer:start()
end


init_spi_display()

disp:begin(ucg.FONT_MODE_TRANSPARENT)
disp:setFont(ucg.font_ncenB24_tr)
disp:clearScreen()
dh = disp:getHeight()
dw = disp:getWidth()

print("Display Height:", dh)
print("Display Width:", dw)

hx711.init(1,2)

print("scale raw zero:", hx711.read(0))

movtimer=tmr.create()
movtimer:register(600, tmr.ALARM_SEMI, read)
movtimer:start()



