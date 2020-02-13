--[[

medido_nopump.lua

simple version of flow counter only, no pump control, pressure sensor
or PID loop

assumes use of Bio-Rad FCH-m-POM-LC flowmeter, Adafruit 2471 ESP8266
processor and Adafruit 1400 power switch

designed for battery power with 4xAA. current consumption is a little
over 100ma, given that AA cells are about 2000-2500 maH this is 20+hrs
of service

times out and goes to sleep after <sleepMins> mins if no flow measured
sensible range for <sleepMins> is 5-10 mins

accumulates running time and total flow as long as it stays awake. can
reset time and flow on front panel

holding down reset button while booting bypasses init.lua and allows
communication via UART with FTDI cable e.g. for code updates

kero flow path plumbed with two one-way valves ... one thru flow
sensor in the correct dir, one in the opposite direction bypassing the
flow meter

since there is no way to know flow direction if we are not running the
pump, it does not make sense to use "diode bridge" of 4 one-way valves
approach of the full medido pump - done this way it only measures in
the correct direction, but allows flow in the opposite direction

DFM Aug 2019

--]]

local flowMeterPin = 7 --GPIO13
local flowResetPin = 2 --GPIO4
local powerOffPin = 1  --GPIO5

local minFlowRate = 2
local lastFlow = 0
local running = false
local accumTime = 0
local dw=128
local dh=64
local seq = {u8g2.DRAW_UPPER_RIGHT, u8g2.DRAW_LOWER_RIGHT, u8g2.DRAW_LOWER_LEFT,u8g2.DRAW_UPPER_LEFT}
local iseq = 1

local pumpStartTime = 0
local pumpStopTime = 0
local pulseCount=0
local lastPulseCount=0
local lastFlowTime=0
local pulsePerOz=77.0 --nominal: 77.6 -- should calibrate for each flowmeter individually
local flowRate=0
local dispRate=0
local pumpFwd=true
local sleepTimer

function startUp()
   dispTimer=tmr.create()
   tmr.register(dispTimer, 10, tmr.ALARM_SEMI, timerCB)
   tmr.start(dispTimer)
end

function cdisp(font, text, x, y)
   local ww, xd
   disp:setFont(font)
   ww=disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   disp:drawStr(xd, y, text)
end

function init_i2c_display()
   local rst  =0 -- GPIO16
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

function gpioCB(lev, pul, cnt)
   if pumpFwd then
      pulseCount=pulseCount + cnt
   else
      pulseCount=pulseCount - cnt
   end
   gpio.trig(flowMeterPin, "up")
end

function gotoSleep()
   print("Goodnight")
   running = false
   print(sleepTimer)
   tmr.stop(sleepTimer)
   gpio.write(powerOffPin, gpio.HIGH)
end

function timerCB()

   local deltaT
   local deltaF
   
   if running then
      tmr.stop(sleepTimer)
      if not tmr.start(sleepTimer) then
	 print(sleepTimer, "Error restarting sleepTimer")
      end
   end
   
   local now = tmr.now()
   deltaT = math.abs(math.abs(now) - math.abs(lastFlowTime)) / (1000000. * 60.) -- mins
   lastFlowTime = now
   deltaF = (pulseCount - lastPulseCount) / pulsePerOz
   lastPulseCount = pulseCount
   flowRate = deltaF / deltaT
   dispRate = dispRate - (dispRate - (deltaF / deltaT)) / 4
   
   if flowRate > minFlowRate and not running then
      -- do accumTime based on last stop and start before resetting start time
      accumTime = accumTime + math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime))
      pumpStartTime = tmr.time()
      running = true
   end
   if flowRate < minFlowRate and running then
      pumpStopTime = tmr.time()
      running = false
   end
   lastFlow = flowRate
   local io=2
   disp:clearBuffer()
   if running then
      runningTime = math.abs(math.abs(tmr.time()) - math.abs(pumpStartTime)) + accumTime
   else
      runningTime = math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime)) + accumTime
   end
   local rt = math.floor(runningTime)
   cdisp(u8g2.font_profont17_mr, string.format("Vol %.1f oz",   pulseCount/pulsePerOz), 1,  0+io)
   if runningTime <= 59 then
      cdisp(u8g2.font_profont17_mr, string.format("Tim %2d sec",  rt), 1, 15+io)
   else
      local min = math.floor(rt/60)
      local sec = math.floor(rt-60*min)
      cdisp(u8g2.font_profont17_mr, string.format("Tim %d:%02d min",  min, sec), 1, 15+io)
   end
   cdisp(u8g2.font_profont17_mr, string.format("Flw %.1f oz/m", dispRate), 1, 30+io)
   if running then
      iseq = iseq + 1
      disp:drawDisc(12, 55+io, 5, seq[iseq % 4 + 1])
   end
   disp:sendBuffer()
   if gpio.read(flowResetPin) < 1 then
      print("Reset")
      running = false
      accumTime = 0
      pulseCount = 0
      lastPulseCount = 0
      pumpStartTime = 0
      pumpStopTime = 0
      flowRate = 0
   end
   tmr.start(dispTimer)
end

-- main program entry point --

pulseCount=0
gpio.mode(flowMeterPin, gpio.INT)
gpio.mode(flowResetPin, gpio.INPUT, gpio.PULLUP)
gpio.trig(flowMeterPin, "up", gpioCB)
gpio.mode(powerOffPin, gpio.OUTPUT)
gpio.write(powerOffPin, gpio.LOW)

init_i2c_display() -- uses (5,6) GPIO14,GPIO12 
disp:clearBuffer()
io=2
cdisp(u8g2.font_profont22_mr, "KeroMeter", 0, 0+io)
cdisp(u8g2.font_profont17_mr, string.format("Cal: %2.2f", pulsePerOz), 0, 25+io)
cdisp(u8g2.font_profont17_mr, "DFM/2019", 0, 45+io)
disp:sendBuffer()

local sleepMins=5
sleepTimer=tmr.create()
tmr.register(sleepTimer, sleepMins*60*1000, tmr.ALARM_SEMI, gotoSleep)
tmr.start(sleepTimer)

splashTimer=tmr.create()
tmr.register(splashTimer, 3000, tmr.ALARM_SINGLE, startUp)
tmr.start(splashTimer)

