--[[

medido pump

this version to work with Adafruit BlueFruit UART BLE module

Possible issues:

1) run in pid mode, e.g. pump speed at 76% but slider at 100% (as expected), then stop and raise PSI limit with PSI slider but pump speed stays at 76%

--]]


ads = require "adc1115"

-- globals seen by all subsystems

medidoEnabled = true 
PIDpGain = 0.01
PIDiGain = 4
PIDpTerm = 0
PIDiTerm = 0
MINpress = 0
MAXpress = 10
pressLimit = (MAXpress + MINpress)/2
pulsePerOzFill = 100.0
pulsePerOzEmpty = 100.0

-- end globals

local dispRstPin        = 0 --GPIO 16
local flowDirPin        = 8 --GPIO 15
local flowMeterPinFill  = 6 --GPIO 12
local flowMeterPinEmpty = 7 --GPIO 13
local flowMeterPinStop  = 5 --GPIO 14
local pwmPumpPin        = 2 --GPIO 4
local powerDownPin      = 1 --GPIO 5 also used to interrupt boot seq if held high on startup

local pulseCountFill=0
local pulseCountEmpty=0
local pulseCountStop=0
local pulseCountBad=0
local pulseStop = 10 -- set # pulses to stop pump on piss tank sensor
local flowRate=0
local lastPulseCountFill=0
local lastPulseCountEmpty=0
local lastPulseCountBad=0
local lastFlowTime=0
local pressZero
local pressScale=3.75
local adcDiv=5.7 -- resistive divider in front of ESP8266 adc from pressure sensor
local currentZero = 0
local minPWM = 50
local maxPWM = 1023
local opPWM = maxPWM
local pumpPWM = 0
local runPWM = 0
local pressPSI = 0
local pumpFwd=true
local saveSetSpeed = 0

local pumpStartTime = 0
local pumpStopTime = 0
local runningTime = 0
local flowCount  = 0
local pumpTimer
local watchTimer
local powerOffTimer
local powerOffMins = 30
local dw=128
local dh=64

function cdisp(font, text, x, y)
   local ww, xd
   if not font then return end
   if not text then return end
   disp:setFont(font)
   ww=disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   disp:drawStr(xd, y, text)
end

function init_i2c_display()

   -- we assume i2c.setup already called
   -- first do a clean reset of the display driver

   gpio.write(dispRstPin, 1)
   tmr.delay(200)
   gpio.write(dispRstPin, 0)
   tmr.delay(200)
   gpio.write(dispRstPin, 1)
   tmr.delay(200)

   -- now set up the api calls
   
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

function gpioCBFill(lev, pul, cnt)
   if pumpFwd then
      pulseCountFill = pulseCountFill + cnt
   else
      pulseCountBad = pulseCountBad + cnt
   end
end

function gpioCBEmpty(lev, pul, cnt)
   if not pumpFwd then
      pulseCountEmpty = pulseCountEmpty + cnt
   else
      pulseCountBad = pulseCountBad + cnt
   end
end

function gpioCBStop(lev, pul, cnt)
   -- code to stop goes here
   pulseCountStop = pulseCountStop + cnt
end

function sendSPI(str, val)
   if not val then return end
   uart.write(0, string.format("("..str..":%4.2f)", val))
end

function setRunSpeed(pw) -- careful .. this is in pwm units 0 .. 1023 ..  not %
   pulseCountBad = 0
   lastPulseCountBad = 0

   sendSPI("rPWM", pw)
   pwm.setduty(pwmPumpPin, pw)
   runPWM = pw
end

oldspd = 0
function setPumpSpeed(ps) -- this is ps units -- 0 to 100%
   
   pumpPWM = math.floor(ps*opPWM/100)
   if pumpPWM < minPWM then pumpPWM = 0 end
   if pumpPWM > maxPWM then pumpPWM = maxPWM end
   sendSPI("pPWM", pumpPWM)
   if pumpPWM ~= oldspd then
      --print("pump speed set to", pumpPWM)
   end
   if runPWM > 0 then
      runPWM = pumpPWM
      setRunSpeed(runPWM)
   end
   oldspd = pumpPWM
end

function setPumpFwd()
   gpio.write(flowDirPin, 0)
   pumpFwd=true
   PIDiTerm = saveSetSpeed
   pulseCountStop = 0 -- reset piss tank flow sensor
   if pumpPWM > 0 then -- just turned on .. note startime
      pumpStartTime = tmr.now()
   end
   setRunSpeed(pumpPWM)
end

function setPumpRev()
   gpio.write(flowDirPin, 1)
   pumpFwd=false
   PIDiTerm = 0
   pulseCountStop = 0 -- reset piss tank flow sensor
   if pumpPWM > 0 then -- just turned on .. note startime
      pumpStartTime = tmr.now()
   end
   setRunSpeed(pumpPWM)
end

function watchDog(T)

end

function powerCB(T)
   print("Powering down .. timeout")
   sendSPI("PowerDown")
   gpio.write(powerDownPin, 1)   
end

function execCmd(k,v)


   -- each time we get any command, restart the poweroff timer
   -- maybe could do tmr.interval(powerOffTimer, powerOffMins*60*1000) instead
   -- of unregistering and registering?
   
   tmr.stop(powerOffTimer)
   tmr.unregister(powerOffTimer)
   powerOffTimer = tmr.create()
   tmr.register(powerOffTimer, powerOffMins*60*1000, tmr.ALARM_SINGLE, powerCB)
   tmr.start(powerOffTimer)   
   
   if k =="Spd" then -- what change was it?
      saveSetSpeed = tonumber(v)
      setPumpSpeed(saveSetSpeed)
      if saveSetSpeed == 0 then
	 --lineLCD(1, "Pump Off")
      end
      --lineLCD(2, "Set Spd", saveSetSpeed, "%d", "%")
      --showLCD()
   elseif k == "Fill" then
      setPumpFwd()
      --lineLCD()
      --lineLCD(1, "Fill")
      --lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      --showLCD()
   elseif k == "Off" then
      --print("pump stop")
      setRunSpeed(0)
      pumpStopTime = tmr.now()
      --lineLCD(1, "Pump Off")
      --lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      --lineLCD(3, "Vol ", flowCount, "%.1f", " oz")
      --lineLCD(4, timeFmt(runningTime))
      --showLCD()
   elseif k == "Empty" then
      setPumpRev()
      --lineLCD()
      --lineLCD(1, "Empty")
      --lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      --showLCD()
   elseif k == "Clear" then
      pulseCountFill = 0
      pulseCountEmpty = 0
      pulseCountBad = 0

      lastPulseCountFill=0
      lastPulseCountEmpty=0
      lastPulseCountBad = 0

      flowCount=0
      runningTime=0
      pumpStartTime=0
      pumpStopTime=0
      sendSPI("rTIM", runningTime)
      --if textLCD[3] then
	-- lineLCD(3, "Vol ", flowCount, "%.1f", " oz")
	-- lineLCD(4, timeFmt(runningTime))
	-- showLCD()
      --end
   elseif k == "CalF" then
      --print("CalFactFill passed in:", tonumber(v))
      pulsePerOzFill = tonumber(v)/10
   elseif k == "CalE" then
      --print("CalFactEmpty passed in:", tonumber(v))
      pulsePerOzEmpty = tonumber(v)/10
   elseif k == "Prs" then
      pressLimit = tonumber(v)/10.0
      pressLimit = math.max(MINpress, math.min(pressLimit, MAXpress))
      --print("pL =", pressLimit, v)
   elseif k == "PwrOff" then
      gpio.write(powerDownPin, 1)
   elseif k == "pMAX" then
      opPWM = tonumber(v)
      if opPWM > maxPWM then opPWM = maxPWM end -- just in case...
      if opPWM < minPWM then opPWM = minPWM end
   else
      --print("Command error:", k, v)
   end
   
   if not seq then seq = 0 end
   
end

function uartCB(data)
   -- called back here with commands coming in from app
   -- commands of the form "(Command:Val)\n"
   -- pickup one per callback cycle and execute it
   local k,v
   k,v = string.match(data, "(%a+)%s*%p*%s*(%d*)")
   execCmd(k,v)
end


local seq=0
local adcAvg=0

function timerCB()
   local msgtype, rspid, rsp
   local pSpd, errsig
   local deltaFFill, deltaFEmpty, deltaF
   local now
   local deltaT
   local dtus
   local ar
   
   if watchTimer then tmr.stop(watchTimer) end
   
   -- send the app a message if we get #pulses > pulseStop  at piss tank sensor
   
   if pulseCountStop > pulseStop then
      sendSPI("pSTP", pulseCountStop)
      pulseCountStop = 0
   end
   
   adcAvg = adcAvg - (adcAvg-adc.read(0)) / 4.0 -- running avg of adc readings
   pressPSI = ((adcDiv*adcAvg/1023)-pressZero) * (pressScale)
   sendSPI("pPSI", pressPSI)

   if pressPSI < 0 then pressPSI = 0 end
      
   flowCount = (pulseCountFill / pulsePerOzFill) - (pulseCountEmpty / pulsePerOzEmpty)

   sendSPI("fCNT", flowCount)

   if pulseCountBad ~= lastPulseCountBad then
      sendSPI("cBAD", pulseCountBad)
      lastPulseCountBad = pulseCountBad
   end
   
   now = tmr.now()
   dtus = now - lastFlowTime
   if dtus < 0 then dtus = dtus + 2147483647 end -- in case of rollover
   if dtus > 1000000 then
      deltaT = dtus / (1000000. * 60.) -- mins
      deltaFFill = (pulseCountFill - lastPulseCountFill) / pulsePerOzFill
      deltaFEmpty = (pulseCountEmpty - lastPulseCountEmpty) / pulsePerOzEmpty   
      deltaF = deltaFFill - deltaFEmpty
      flowRate = flowRate - (flowRate - (deltaF / deltaT))/1.2
      sendSPI("fRAT", flowRate)
      sendSPI("fDEL", deltaF)
      sendSPI("fDET", deltaT)
      lastPulseCountFill = pulseCountFill
      lastPulseCountEmpty = pulseCountEmpty   
      lastFlowTime = now
   end
   
   if runPWM > 0 then
      runningTime = math.abs(math.abs(tmr.now()) - math.abs(pumpStartTime)) / 1000000. -- secs
   else
      runningTime = math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime)) / 1000000.
   end

   -- don't send time if pump not on .. confuses graph on iPhone
   
   if runPWM ~= 0 then sendSPI("rTIM", runningTime) end

   if pumpFwd and runPWM > 0 and (PIDiGain ~= 0 or PIDpGain ~= 0) then
      errsig  = pressLimit - pressPSI
      PIDpTerm = errsig * PIDpGain
      PIDiTerm = math.max(0, math.min(PIDiTerm + errsig * PIDiGain, 100))
      pSpd = PIDpTerm + PIDiTerm
      pSpd = math.max(0, math.min(pSpd, saveSetSpeed))
      setPumpSpeed(pSpd) -- side effect: sets pumpPWM within bounds
      setRunSpeed(pumpPWM) -- side effect: sets runPWM
      --print("pressPSI, errsig, PIDpTerm, PIDiTerm, pSpd",
	--    pressPSI, errsig, PIDpTerm, PIDiTerm, pSpd)
   end
   
   if medidoEnabled then
      tmr.start(watchTimer)
      tmr.start(pumpTimer)
   end
   
   seq = seq + 1
   if seq % 10 == 0 then
      sendSPI("Batt", ads.readAdc(0) or 0)
   end
   if seq % 5 == 0 then
      sendSPI("Curr", 100 * ((ads.readAdc(1, 4) or 0) - currentZero) )
   end
   

end

-- Main prog and init seciton starts here

-- First init the UART to talk BLE to the app
uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
uart.on("data","\n", uartCB, 0)

--uart.write(0, "starting 9600 baud")

--uart.write(0, "AT\n")
--uart.write(0,"AT+BLEPOWERLEVEL=4\r\n")
--uart.write(0,"AT+BLEGETADDR\n")
--uart.write(0,"AT+BLEGETRSSI\n")

-- Initialize the i2c bus

local sda, scl = 4, 3

i2c.setup(0, sda, scl, i2c.SLOW)

-- Set up 1KHz pwm signal to drive pump

pwm.setup(pwmPumpPin, 1000, 0)
pwm.setduty(pwmPumpPin, 0)

-- Get a zero cal point on the current sensor

for i = 1, 10, 1 do
   currentZero = currentZero + (ads.readAdc(1, 4) or 0)
end

currentZero = currentZero / 10.0

-- Get a zero cal point on the pressure transducer

pressZero = adcDiv * adc.read(0) / 1023

for i=1,50,1 do
   pressZero = pressZero - (pressZero - adcDiv * adc.read(0) / 1023)/10
end

-- Set up the gpio interrupt to catch pulses from the flowmeters

gpio.mode(flowMeterPinFill, gpio.INT)
gpio.trig(flowMeterPinFill, "down", gpioCBFill)

gpio.mode(flowMeterPinEmpty, gpio.INT)
gpio.trig(flowMeterPinEmpty, "down", gpioCBEmpty)

gpio.mode(flowMeterPinStop, gpio.INT)
gpio.trig(flowMeterPinStop, "down", gpioCBStop)

-- Preset pump speed to 0, set FWD direction

gpio.mode(flowDirPin, gpio.OUTPUT)
setPumpSpeed(0)
setPumpFwd()

-- Setup power down pin, taking it high turns off the pump

gpio.mode(powerDownPin, gpio.OUTPUT)
gpio.write(powerDownPin, 0)

-- Set up the OLED display panel and put up an initial screen

---init_i2c_display()
---disp:clearBuffer()
---io=2
---cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
---cdisp(u8g2.font_profont17_mr, "BLE v1.0", 0, 20+io)

sendSPI("Init", 0)
sendSPI("rPWM", 0)

-- Create the mainloop timer and callback

pumpTimer=tmr.create()
tmr.register(pumpTimer, 200, tmr.ALARM_SEMI, timerCB)
tmr.start(pumpTimer)

-- Create a timer for poweroff

powerOffTimer = tmr.create()
tmr.register(powerOffTimer, powerOffMins*60*1000, tmr.ALARM_SINGLE, powerCB)
tmr.start(powerOffTimer)

-- Set up watchdog timer, let the callback loop start it

watchTimer=tmr.create()
tmr.register(watchTimer, 2000, tmr.ALARM_SINGLE, watchDog)
