function startUp()
   dispTimer=tmr.create()
   tmr.register(dispTimer, 10, tmr.ALARM_SEMI, timerCB)
   tmr.start(dispTimer)
end

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

   local rst  =7 -- GPIO13
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


function rotaryCB(type, pos, time)
   deltaT=math.abs(math.abs(time)-math.abs(lastTime))/1000000
   mins=time/(60*1000000)
   --print(string.format("type:%2d pos:%4d time:%12d deltaT:%3.3f mins:%3.2f", type, pos, time, deltaT, mins))
   if type == rotary.TURN then
      rotaryPos=pos
      local mult = 0.25
      local deltaR = math.abs(rotaryPos - lastPos)
      mult = mult * math.max(math.min(deltaR, 6), 1)
      pumpSpeed = pumpSpeed + mult*(rotaryPos - lastPos)
      if pumpSpeed < 0 then pumpSpeed = 0 end
      if pumpSpeed > 100 then pumpSpeed=100 end
      lastPos = pos
   end
   if type == rotary.DBLCLICK then
      saveCount = pulseCount 
   end
   if type == rotary.LONGPRESS then
      pulseCount = 0
      lastPulseCount=0
      flowRate=0
   end
   lastTime = time
end

function gpioCB(lev, pul, cnt)
   pulseCount=pulseCount+cnt
   gpio.trig(8, "up")
end

function timerCB()
   --print("timerCB")
   local now = tmr.now()
   local deltaT = math.abs(math.abs(now) - math.abs(lastFlowTime)) / (1000000. * 60.) -- mins
   lastFlowTime = now
   local deltaF = (pulseCount - lastPulseCount) / pulsePerOz
   lastPulseCount = pulseCount
   flowRate = flowRate - (flowRate - (deltaF / deltaT))/1 -- no avg for now
   --if flowRate < 0 then flowRate = 0 end -- handle correctly in rotary button callback
   local io=2
   disp:clearBuffer()
   cdisp(u8g2.font_profont17_mr, string.format("Cap: %.1f oz",   saveCount/pulsePerOz),  1,  0+io)
   cdisp(u8g2.font_profont17_mr, string.format("Vol: %.1f oz",   pulseCount/pulsePerOz), 1, 15+io)
   cdisp(u8g2.font_profont17_mr, string.format("Flw: %.1f oz/m", flowRate),              1, 30+io)   
   disp:drawFrame(1, 52, 110, 12)
   disp:drawBox(1, 52, (pumpSpeed/100)*110, 12)
   disp:sendBuffer()
   tmr.start(dispTimer)
end


lastTime=0
rotaryPos=0

lastPos=0
pulseCount=0
lastPulseCount=0
flowTime=0
lastFlowTime=0
saveCount=0
pulsePerOz=355.0
pumpSpeed = 0
flowRate=0

rotary.setup(0,2,1,4) -- GPIO4,GPIO5,GPIO2

rotary.on(0, rotary.ALL, rotaryCB)

gpio.mode(8, gpio.INT)

pulseCount=0

gpio.trig(8, "up", gpioCB)

init_i2c_display()

disp:clearBuffer()

io=2
cdisp(u8g2.font_profont22_mr, "LuaPump", 0, 0+io)
cdisp(u8g2.font_profont17_mr, "Version 1.0", 0, 25+io)
disp:sendBuffer()

splashTimer=tmr.create()
tmr.register(splashTimer, 4000, tmr.ALARM_SINGLE, startUp)
tmr.start(splashTimer)
