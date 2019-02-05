--[[

medido pump

--]]


server = require "espWebServer"

-- globals seen by all subsystems

medidoEnabled = true 
pressLimit = 15
PIDpGain = 0
PIDiGain = 0
PIDpTerm = 0
PIDiTerm = 0

-- end globals


local flowDirPin   = 3 --GPIO0
local flowMeterPin = 7 --GPIO13
local pwmPumpPin   = 8 --GPIOxx
local pulseCount=0
local flowRate=0
local lastPulseCount=0
local lastFlowTime=0
local pulsePerOz=77.6
local pressZero
local pressScale=3.75
local adcDiv=5.7 -- resistive divider in front of adc   
local minPWM = 50
local maxPWM = 1023
local lastPWM = 0
local pumpPWM = 0
local pressPSI = 0
local pumpFwd=true
local saveSetSpeed = 0

local pumpStartTime = 0
local pumpStopTime = 0
local runningTime = 0

local flowCount  = 0

local gotCalFact = false

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
      print("clearing textLCD")
      for i = 1, 4, 1 do
	 textLCD[i]=nil
      end
      return
   end
   print("lineLCD: line, val", line, val)
   if not val then
      textLCD[line] = txt
   else
      textLCD[line] = txt .. " " .. string.format(fmt, val) .. sfx
   end
end

function showLCD()
   local io = 2
   disp:clearBuffer()
   for i = 1, 4, 1 do
      if textLCD[i] then
	 cdisp(u8g2.font_profont17_mr, textLCD[i], 1,  (i-1)*15+io)
      end
   end
   disp:sendBuffer()
end

function gpioCB(lev, pul, cnt)
   if pumpFwd then
      pulseCount=pulseCount + cnt
   else
      pulseCount=pulseCount - cnt
   end
   gpio.trig(flowMeterPin, "up")
end

local function setPumpSpeed(ps)
   pumpPWM = math.floor(ps*maxPWM/100)
   if pumpPWM < minPWM then pumpPWM = 0 end
   if pumpPWM > 1023 then pumpPWM = maxPWM end
   pwm.setduty(pwmPumpPin, pumpPWM)
   if lastPWM == 0 and pumpPWM > 0 then -- just turned on .. note startime
      print("pump start")
      pumpStartTime = tmr.now()
   end
   if lastPWM > 0 and pumpPWM == 0 then -- just turned off .. note stop time
      print("pump stop")
      pumpStopTime = tmr.now()
   end
   --print("PWM set to:", pumpPWM)
   lastPWM = pumpPWM
end

local function setPumpFwd()
   gpio.write(flowDirPin, gpio.LOW)
   pumpFwd=true
   print("Fwd")
end

local function setPumpRev()
   gpio.write(flowDirPin, gpio.HIGH)
   pumpFwd=false
   print("Rev")
end

local seq=0
local dt

function timerCB()
   local pSpd, errsig
   local now = tmr.now()
   local deltaT = math.abs(math.abs(now) - math.abs(lastFlowTime)) / (1000000. * 60.) -- mins
   lastFlowTime = now
   flowCount = pulseCount / pulsePerOz
   local deltaF = (pulseCount - lastPulseCount) / pulsePerOz
   lastPulseCount = pulseCount
   flowRate = flowRate - (flowRate - (deltaF / deltaT))/4
   if pumpPWM > 0 then
      runningTime = math.abs(math.abs(tmr.now()) - math.abs(pumpStartTime)) / 1000000. -- secs
   else
      runningTime = math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime)) / 1000000.
   end
   
   pressPSI = ((adcDiv*adc.read(0)/1023)-pressZero) * (pressScale)

   if pumpFwd and (PIDiGain ~= 0 or PIDpGain ~= 0) then
      errsig  = pressLimit - pressPSI
      PIDpTerm = errsig * PIDpGain
      PIDiTerm = math.max(0, math.min(PIDiTerm + errsig * PIDiGain, 100))
      pSpd = PIDpTerm + PIDiTerm
      pSpd = math.max(0, math.min(pSpd, saveSetSpeed))
      setPumpSpeed(pSpd)
      --print("pressPSI, errsig, PIDpTerm, PIDiTerm, pSpd",
	--    pressPSI, errsig, PIDpTerm, PIDiTerm, pSpd)
   end
   
   if medidoEnabled then
      tmr.start(pumpTimer)
   end
   dt = (tmr.now() - now) / 1000
   
end

local saveTable={}

function xhrCB(varTable)
   for k,v in pairs(varTable) do
      if saveTable[k] ~= v then   -- if there was a change
	 saveTable[k] = v
	 local kk, idx
	 if (not gotCalFact) and (k ~= "cF" and tonumber(v) ~= 0) then
	    print("Attempt to command before calFact - rejected:", k, v)
	    kk = nil
	 else
	    kk = k
	 end
	 if kk == "pS" then -- what change was it?
	    saveSetSpeed = tonumber(v)
	    setPumpSpeed(saveSetSpeed)
	    if saveSetSpeed == 0 then
	       lineLCD(1, "Pump Off")
	    end
	    if pumpFwd and saveSetSpeed ~= 0 then
	       lineLCD()
	       lineLCD(1, "Fill")
	       PIDiTerm = saveSetSpeed
	    end
	    if not pumpFwd and saveSetSpeed ~= 0 then
	       lineLCD()
	       lineLCD(1, "Empty")
	       PIDiTerm = 0
	    end
	    lineLCD(2, "Set Spd", saveSetSpeed, "%d", "%")
	    showLCD()
	 elseif kk == "pB" then
	    idx = tonumber(v)
	    if idx == 0     then -- "Idle" (no command)
	       --
	    elseif idx == 1 then -- "Fill"
	       setPumpFwd()
	       lineLCD()
	       lineLCD(1, "Fill")
	       lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
	       showLCD()
	    elseif idx == 2 then -- "Off"
	       saveSetSpeed = 0
	       setPumpSpeed(saveSetSpeed)
	       lineLCD(1, "Pump Off")
	       lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
	       lineLCD(3, "Vol ", flowCount, "%.1f", " oz")
	       lineLCD(4, timeFmt(runningTime))
	       showLCD()
	    elseif idx == 3 then -- "Empty"
	       setPumpRev()
	       lineLCD()
	       lineLCD(1, "Empty")
	       lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
	       showLCD()
	    else
	       print("idx error:", idx)
	    end
	 elseif kk == "pC" and tonumber(v) == 1 then
	    print("Clear")
	    pulseCount = 0
	    lastPulseCount=0
	    flowCount=0
	    runningTime=0
	    pumpStartTime=0
	    pumpStopTime=0
	    if textLCD[3] then
	       lineLCD(3, "Vol ", flowCount, "%.1f", " oz")
	       lineLCD(4, timeFmt(runningTime))
	       showLCD()
	    end
	 elseif kk == "cF" then
	    print("calFact passed in:", tonumber(v))
	    pulsePerOz = tonumber(v)/100
	    gotCalFact = true
	 end
      end
   end
   
   --local tn = tmr.now()
   --drawLCD(runningTime, flowRate, pressPSI, pulseCount, pumpPWM)
   --local dt = (tmr.now() - tn)/1000
   
   seq = seq + 1
   if seq > 100 then
      seq = 0
      print("Heap, dt(ms):", node.heap(), dt)
   end

   local ippo = math.floor(pulsePerOz * 100 + 0.5)
   return string.format("%f,%f,%f,%f,%f,%f,%f",
			node.heap(),flowCount,flowRate,runningTime,ippo,pressPSI, pumpPWM)
end


local ip=wifi.sta.getip()
local bs=1024
print("Starting heap:", node.heap())
server.setAjaxCB(xhrCB)
server.start(80, bs)
print("Starting web server on port 80, buffer size:", bs)
print("IP Address: ", ip)

setPumpSpeed(0)
setPumpFwd()
pwm.setup (pwmPumpPin,   1000, 0)

pressZero = adcDiv * adc.read(0) / 1023

for i=1,50,1 do
   pressZero = pressZero - (pressZero - adcDiv * adc.read(0) / 1023)/10
end

init_i2c_display() -- uses (5,6) GPIO14,GPIO12 
disp:clearBuffer()
io=2
cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
cdisp(u8g2.font_profont17_mr, "Version 1.0", 0, 20+io)
cdisp(u8g2.font_profont17_mr, ip, 0, 40+io)
disp:sendBuffer()

gpio.mode (flowDirPin,   gpio.OUTPUT)
gpio.write(flowDirPin,   gpio.LOW)

gpio.mode (flowMeterPin, gpio.INT)
gpio.trig (flowMeterPin, "up", gpioCB)

pumpTimer=tmr.create()
tmr.register(pumpTimer, 200, tmr.ALARM_SEMI, timerCB)
tmr.start(pumpTimer)
print("End of main - heap:", node.heap())


