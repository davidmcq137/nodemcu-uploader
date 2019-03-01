function swiendsleep()
   --print("in swiendsleep")
   dispSleepTimer:start()   
end

function swiendread()
   --print("in swiendread")
   readtimer:start()
end

function swiendrst() -- only call on startup
   --print("in swiendrst")
   switec.reset(0)
   swiendread()
end

function dispSleep()
   disp:setPowerSave(1)
   lock = false
   lockwt = 0
   iwt = 1
   jwt = 1
   wtboxcar={}
   noreadings = true
end

function u8g2_prepare()
  disp:setFontRefHeightExtendedText()
  disp:setDrawColor(1)
  disp:setFontPosBottom()
  disp:setFontDirection(0)
end

function init_i2c_display()
    -- SDA and SCL can be assigned freely to available GPIOs
    local sda = 2 -- now GPIO4 was: GPIO14
    local scl = 1 -- now GPIO5 was: GPIO12
    local sla = 0x3c
    --print("init .. before i2c setup")
    i2c.setup(0, sda, scl, i2c.SLOW)
    --print("init .. before u8g2 call")
    disp = u8g2.ssd1306_i2c_128x64_noname(0, sla)
    --print("init .. after u8g2 call")
end


calib = 11010.8
zero = -17800
seq = {u8g2.DRAW_UPPER_RIGHT, u8g2.DRAW_LOWER_RIGHT, u8g2.DRAW_LOWER_LEFT,u8g2.DRAW_UPPER_LEFT}
iseq = 1
wtboxcar={}
iwt = 1
jwt = 1
wtboxlen=5
lock = false
lockwt = 0
noreadings = true
tgtweight = 270

function read()
   local wt = (hx711.read(0) - zero)/calib
   tmr.delay(100)
   print("in read, wt:", wt)

end

init_i2c_display()
u8g2_prepare()

dh = 64
dw = 128

--print("Display Height:", dh)
--print("Display Width:", dw)

hx711.init(4,0)

local zs = 0
for i=1, 5, 1 do
   tmr.delay(100)
   zs = zs + hx711.read(0)
end
zero = zs/5

print("scale raw zero:", zero)

disp:setFont(u8g2.font_6x10_tf)
text = string.format("Hazel Scale V%.1f", 1.0)
ww = disp:getStrWidth(text)
disp:drawStr(dw/2 - ww/2, 30, text)

disp:setFont(u8g2.font_6x10_tf)
text = string.format("Raw Zero: %d", zero)
ww = disp:getStrWidth(text)
disp:drawStr(dw/2 - ww/2, 40, text)

text = string.format("Cal Factor: %5.2f", calib)
ww = disp:getStrWidth(text)
disp:drawStr(dw/2 - ww/2, 50, text)

text = string.format("Tgt Weight: %5.2f", tgtweight)
ww = disp:getStrWidth(text)
disp:drawStr(dw/2 - ww/2, 60, text)

disp:sendBuffer()

readtimer=tmr.create()
readtimer:register(1000, tmr.ALARM_SEMI, read)
--readtimer:start()

dispSleepTimer=tmr.create()
dispSleepTimer:register(5000, tmr.ALARM_SEMI, dispSleep)

-- setup motor control: channel 0, pins 5,6,7,8 and 200 deg/sec

switec.setup(0,5,6,7,8,200)-- position specified in 1/3s of degree so it goes from 0 to 945 (315 degrees full scale * 3)

switec.moveto(0, -1000, swiendrst) -- force against CCW stop before reset (done in swiendrst())
