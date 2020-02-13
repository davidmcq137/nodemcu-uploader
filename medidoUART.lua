--[[

medido pump

this version to work with Adafruit BlueFruit UART BLE module

Possible issues:

1) run in pid mode, e.g. pump speed at 76% but slider at 100% (as expected), then stop and raise PSI limit with PSI slider but pump speed stays at 76%

--]]


mcp = require "mcp23008"
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
pulsePerOz = 77.6
pulsePerOzFill = 100.0
pulsePerOzEmpty = 100.0

-- end globals

local dispRstPin   = 1 --MCP23008
local flowDirPin   = 2 --MCP23008
local flowSensePin = 3 --MCP23008
local flowMeterPin = 8 --GPIO15
local pwmPumpPin   = 2 --GPIO4
local pulseCount=0
local flowRate=0
local lastPulseCount=0
local lastFlowTime=0
local pressZero
local pressScale=3.75
local adcDiv=5.7 -- resistive divider in front of adc   
local minPWM = 50
local maxPWM = 1023
local lastPWM = 0
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

   mcp.gpioWritePin(dispRstPin, 1)
   tmr.delay(200)
   mcp.gpioWritePin(dispRstPin, 0)
   tmr.delay(200)
   mcp.gpioWritePin(dispRstPin, 1)
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

function gpioCB(lev, pul, cnt)
   if pumpFwd then
      pulseCount=pulseCount + cnt
   else
      pulseCount=pulseCount - cnt
   end
   gpio.trig(flowMeterPin, "up")
end

function setRunSpeed(pw) -- careful .. this is in pwm units 0 .. 1023 ..  not %
   sendSPI("rPWM", pw)
   pwm.setduty(pwmPumpPin, pw)
   runPWM = pw
end

oldspd = 0
function setPumpSpeed(ps) -- this is ps units -- 0 to 100%
   pumpPWM = math.floor(ps*maxPWM/100)
   if pumpPWM < minPWM then pumpPWM = 0 end
   if pumpPWM > 1023 then pumpPWM = maxPWM end
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
   mcp.gpioWritePin(flowDirPin, 0)
   pumpFwd=true
   pulsePerOz = pulsePerOzFill
   PIDiTerm = saveSetSpeed
   --print("setPumpFwd:", pumpPWM)
   --print("PIDiTerm:", saveSetSpeed)
   if pumpPWM > 0 then -- just turned on .. note startime
      --print("pump start fwd")
      pumpStartTime = tmr.now()
   end
   setRunSpeed(pumpPWM)
   --print("Pump Running Fwd")
end

function setPumpRev()
   mcp.gpioWritePin(flowDirPin, 1)
   pumpFwd=false
   pulsePerOz = pulsePerOzEmpty
   PIDiTerm = 0
   --print("setPumpRev:", pumpPWM)
   if pumpPWM > 0 then -- just turned on .. note startime
      --print("pump start rev")
      pumpStartTime = tmr.now()
   end
   setRunSpeed(pumpPWM)
   --print("Pump Running Rev")
end

function watchDog(T)
   --print("***watchDog***", T)
end

function execCmd(k,v)

   --print("execCmd: k, v", k, v)
   
   if k =="Speed" then -- what change was it?
      saveSetSpeed = tonumber(v)
      setPumpSpeed(saveSetSpeed)
      if saveSetSpeed == 0 then
	 lineLCD(1, "Pump Off")
      end
      lineLCD(2, "Set Spd", saveSetSpeed, "%d", "%")
      showLCD()
   elseif k == "Fill" then
      setPumpFwd()
      lineLCD()
      lineLCD(1, "Fill")
      lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      showLCD()
   elseif k == "Off" then
      setRunSpeed(0)
      --print("pump stop")
      pumpStopTime = tmr.now()
      lineLCD(1, "Pump Off")
      lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      lineLCD(3, "Vol ", flowCount, "%.1f", " oz")
      lineLCD(4, timeFmt(runningTime))
      showLCD()
   elseif k == "Empty" then
      setPumpRev()
      lineLCD()
      lineLCD(1, "Empty")
      lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      showLCD()
   elseif k == "Clear" then -- ? why 1?  and tonumber(v) == 1 then
      --print("Clear")
      pulseCount = 0
      lastPulseCount=0
      flowCount=0
      runningTime=0
      pumpStartTime=0
      pumpStopTime=0
      sendSPI("rTIM", runningTime)
      if textLCD[3] then
	 lineLCD(3, "Vol ", flowCount, "%.1f", " oz")
	 lineLCD(4, timeFmt(runningTime))
	 showLCD()
      end
   elseif k == "CalFactFill" then
      --print("calFact passed in:", tonumber(v))
      pulsePerOzFill = tonumber(v)/10
   elseif k == "CalFactEmpty" then
      pulsePerOzEmpty = tonumber(v)/10
   elseif k == "Press" then
      pressLimit = tonumber(v)/10.0
      pressLimit = math.max(MINpress, math.min(pressLimit, MAXpress))
      --print("pL =", pressLimit, v)
   else
      --print("Command error:", k, v)
   end
   
   --local tn = tmr.now()
   --drawLCD(runningTime, flowRate, pressPSI, pulseCount, pumpPWM)
   --local dt = (tmr.now() - tn)/1000

   if not seq then seq = 0 end
   
end

function sendAT(str)
   uart.write(0, str)
end

function sendSPI(str, val)
   if not val then return end
   uart.write(0, string.format("("..str..":%4.2f)", val))
end

local ATreply

function ATcmdCB(data)
   --print("in ATcmdCB - data: "..data)
   if not ATreply then
      ATreply = data
   else
      ATreply = ATreply .. "|" .. data
   end
end

function uartCB(data)
   -- called back here with commands coming in from app
   -- commands of the form "(Command:Val)\n"
   -- pickup one per callback cycle and execute it
   local k,v
   --print("data: "..data)
   k,v = string.match(data, "(%a+)%s*%p*%s*(%d*)")
   --print("k,v:", k, v)
   execCmd(k,v)
end


local seq=0
local dt
local adcAvg=0

function timerCB()
   local msgtype, rspid, rsp
   local pSpd, errsig
   local now = tmr.now()
   local deltaT = math.abs(math.abs(now) - math.abs(lastFlowTime)) / (1000000. * 60.) -- mins
   tmr.stop(watchTimer)
   lastFlowTime = now

   adcAvg = adcAvg - (adcAvg-adc.read(0)) / 4.0 -- running avg of adc readings
   pressPSI = ((adcDiv*adcAvg/1023)-pressZero) * (pressScale)
   sendSPI("pPSI", pressPSI)

   if pressPSI < 0 then pressPSI = 0 end
      
   flowCount = pulseCount / pulsePerOz

   if seq % 30 == 0 then
      --print("ppo, ppo(corr), pPsi", pulsePerOz, pulsePerOz + pulsePerOz * fFactor * (5-pressPSI)/5, pressPSI)
   end
   
   sendSPI("fCNT", flowCount)
   local deltaF = (pulseCount - lastPulseCount) / pulsePerOz
   lastPulseCount = pulseCount
   flowRate = flowRate - (flowRate - (deltaF / deltaT))/1.2
   sendSPI("fRAT", flowRate)
   if runPWM > 0 then
      runningTime = math.abs(math.abs(tmr.now()) - math.abs(pumpStartTime)) / 1000000. -- secs
   else
      runningTime = math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime)) / 1000000.
   end
   sendSPI("rTIM", runningTime)
   

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
      watchTimer=tmr.create()
      tmr.register(watchTimer, 2000, tmr.ALARM_SINGLE, watchDog)
      tmr.start(watchTimer)
      tmr.start(pumpTimer)
   end
   
   dt = (tmr.now() - now) / 1000

   seq = seq + 1
   if seq % 100 == 0 then
      local v1 = ads.readAdc(1)
      sendSPI("volt1", v1)
      sendSPI("Heap", node.heap()/1000.)
      --print("Heap, dt(ms), volt1:", node.heap(), dt, v1)
   end

end


-- Main prog and init seciton starts here

-- First init the UART to talk BLE to the app

uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)

-- Set up callback function for commands coming back from BLE

--print("*******************************UART set up")

uart.on("data","\n", uartCB, 0)

--sendAT("AT+BLEGETADDR\r\n")

--sendAT("AT+BLEGETRSSI\r\n")

-- now switch the BLE device to UART mode and set up the uart callback

--sendAT("+++\r\n")

--if not ATreply then ATreply = "nil" end

--print("ATreply: "..ATreply)

-- Initialize the i2c bus

local sda, scl = 4, 3

---i2c.setup(0, sda, scl, i2c.SLOW)

-- Set up the MCP23008 GPOI extender to all 8 pins as outputs

---mcp.gpioSetIOdir(0x00) -- set MCP23008 gpio extender to all outputs

-- Start 1KHz pwm signal to drive pump

pwm.setup(pwmPumpPin, 1000, 0)
pwm.setduty(pwmPumpPin, 0)

-- Get a zero cal point on the pressure transducer

pressZero = adcDiv * adc.read(0) / 1023

for i=1,50,1 do
   pressZero = pressZero - (pressZero - adcDiv * adc.read(0) / 1023)/10
end

-- set the (extended) gpio pin to enable pulses from the flow sensor

---mcp.gpioWritePin(flowSensePin, 1)

-- Set up the gpio interrupt to catch pulses from the flowmeter

gpio.mode(flowMeterPin, gpio.INT)
gpio.trig(flowMeterPin, "up", gpioCB)

-- Preset pump speed to 0, set FWD direction

setPumpSpeed(0)
setPumpFwd()

-- See if the BLE module is alive

--print("**********************************************************************")

---rsp=ble.spi_command_check_OK("ATI")
---print("rsp from ATI:")
---print(rsp)

---rsp=ble.spi_command_generic("AT+BLEPOWERLEVEL=4")
---print("rsp from AT get power level:")
---print(rsp)

---tmr.delay(1000)

---rsp=ble.spi_command_check_OK("AT+BLEGETADDR")
---print("rsp from AT ble get addr:")
---print(rsp)

---tmr.delay(1000)

--[[
local RSSI = "not connected"
if ble.spi_connected() then
   print("connected")
   RSSI = ble.spi_command_check_OK("AT+BLEGETRSSI", 2000)
   if not RSSI then RSSI = "error" end
   print("rsp from AT ble get RSSI:")
   print(RSSI)
else
   print("not connected")
end
--]]

--print(" ")


-- Set up the OLED display panel and put up an initial screen

---init_i2c_display()
---disp:clearBuffer()
---io=2
---cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
---cdisp(u8g2.font_profont17_mr, "BLE v1.0", 0, 20+io)

---print("#RSSI:", #RSSI)
---RSSI = RSSI:gsub("\n","")
---print("#RSSI:", #RSSI)

---print("Signal: " .. RSSI .. " dbm")
---cdisp(u8g2.font_profont17_mr, "BT: " .. RSSI .. " dbm", 0, 40+io)
---disp:sendBuffer()

sendSPI("Init", 0)
sendSPI("rPWM", 0)

-- Create the mainloop timer and callback

pumpTimer=tmr.create()
tmr.register(pumpTimer, 200, tmr.ALARM_SEMI, timerCB)
tmr.start(pumpTimer)

-- Create a watchdog in case the mainloop hangs

watchTimer=tmr.create()
tmr.register(watchTimer, 2000, tmr.ALARM_SINGLE, watchDog)
tmr.start(watchTimer)
