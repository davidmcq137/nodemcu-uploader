--[[

medido pump

this version to work with Adafruit BlueFruitSPI BLE module

--]]


bleSPI = require "bleSPI"
mcp = require "mcp23008"
ads = require "adc1115"

-- globals seen by all subsystems

medidoEnabled = true 
PIDpGain = 1
PIDiGain = 10
PIDpTerm = 0
PIDiTerm = 0
MINpress = 0
MAXpress = 15
pressLimit = (MAXpress + MINpress)/2

-- end globals

local dispRstPin   = 1 --MCP23008
local flowDirPin   = 2 --MCP23008
local flowMeterPin = 8 --GPIO15
local pwmPumpPin   = 2 --GPIO4
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
local pumpTimer
local watchTimer

local gotCalFact = false

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

function setPumpSpeed(ps)
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
   sendSPI("pumpPWM", pumpPWM)
end

function setPumpFwd()
   mcp.gpioWritePin(flowDirPin, 0)
   pumpFwd=true
   print("Fwd")
end

function setPumpRev()
   mcp.gpioWritePin(flowDirPin, 1)
   pumpFwd=false
   print("Rev")
end

function watchDog(T)
   print("***watchDog***", T)
end

local seq=0
local dt

function execCmd(k,v)

   print("execCmd: k, v", k, v)
   
   if k =="Speed" then -- what change was it?
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
   elseif k == "Fill" then
      setPumpFwd()
      lineLCD()
      lineLCD(1, "Fill")
      lineLCD(2, "Set Spd ", saveSetSpeed, "%d", "%")
      showLCD()
   elseif k == "Off" then
      saveSetSpeed = 0
      setPumpSpeed(saveSetSpeed)
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
   elseif k == "CalFact" then
      --print("calFact passed in:", tonumber(v))
      pulsePerOz = tonumber(v)/100
      gotCalFact = true
   elseif k == "Pressure" then
      pressLimit = tonumber(v/10)
      pressLimit = math.max(MINpress, math.min(pressLimit, MAXpress))
      --print("pL =", pressLimit, v)
   else
      print("Command error:", k, v)
   end
   
   --local tn = tmr.now()
   --drawLCD(runningTime, flowRate, pressPSI, pulseCount, pumpPWM)
   --local dt = (tmr.now() - tn)/1000

   if not seq then seq = 0 end
   
   seq = seq + 1
   if seq > 100 then
      seq = 0
      --print("Heap, dt(ms):", node.heap(), dt)
   end
   
   --local ippo = math.floor(pulsePerOz * 100 + 0.5)
   --return string.format("%f,%f,%f,%f,%f,%f,%f",
   --  node.heap(),flowCount,flowRate,runningTime,ippo,pressPSI, pumpPWM)
end



function sendSPI(str, val)
   msgtype,rspid,rsp = bleSPI.spi_cmd(_SDEP_BLEUART_TX, string.format("("..str..":%4.2f)", val))
   if not rsp then print("SPI TX Error", msgtype, rspid, rsp) end
end


function timerCB()
   local msgtype, rspid, rsp
   local pSpd, errsig
   local now = tmr.now()
   local deltaT = math.abs(math.abs(now) - math.abs(lastFlowTime)) / (1000000. * 60.) -- mins
   tmr.stop(watchTimer)
   lastFlowTime = now
   flowCount = pulseCount / pulsePerOz
   sendSPI("flowCount", flowCount)
   local deltaF = (pulseCount - lastPulseCount) / pulsePerOz
   lastPulseCount = pulseCount
   flowRate = flowRate - (flowRate - (deltaF / deltaT))/4
   sendSPI("flowRate", flowRate)
   if pumpPWM > 0 then
      runningTime = math.abs(math.abs(tmr.now()) - math.abs(pumpStartTime)) / 1000000. -- secs
   else
      runningTime = math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime)) / 1000000.
   end
   sendSPI("runTime", runningTime)
   
   pressPSI = ((adcDiv*adc.read(0)/1023)-pressZero) * (pressScale)
   sendSPI("pressPSI", pressPSI)

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
      watchTimer=tmr.create()
      tmr.register(watchTimer, 2000, tmr.ALARM_SINGLE, watchDog)
      tmr.start(watchTimer)
      tmr.start(pumpTimer)
   end
   
   dt = (tmr.now() - now) / 1000

   -- check SPI for commands coming in from app
   -- commands of the form "(Command:Val)"
   -- pickup one per callback cycle and execute it
   
   msgtype, rspid, rsp = bleSPI.spi_cmd(_SDEP_BLEUART_RX)
   if #rsp ~= 0 then
      print("msgtype, rspid, rsp", msgtype, rspid, rsp)
      local k,v = string.match(rsp, "(%a+):?(%d*)")
      execCmd(k,v)
   end

end


-- Main prog and init seciton starts here

print("Main Prog")

-- First init the SPI bus to talk BLE to the app
-- this routine will do the low-level spi init

bleSPI.spi_init(1, 1, 0, 0) -- args are id (HSPI must be 1), cs, irq, reset

-- Initialize the i2c bus
print("i2c")
local sda, scl = 4, 3
i2c.setup(0, sda, scl, i2c.SLOW)

-- Set up the MCP23008 GPOI extender to all 8 pins as outputs

mcp.gpioSetIOdir(0x00) -- set MCP23008 gpio extender to all outputs

-- Start 1KHz pwm signal to drive pump

pwm.setup(pwmPumpPin, 1000, 0)
pwm.setduty(pwmPumpPin, 0)

-- Get a zero cal point on the pressure transducer

pressZero = adcDiv * adc.read(0) / 1023

for i=1,50,1 do
   pressZero = pressZero - (pressZero - adcDiv * adc.read(0) / 1023)/10
end

-- Set up the OLED display panel and put up an initial screen

init_i2c_display()
disp:clearBuffer()
io=2
cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
cdisp(u8g2.font_profont17_mr, "Version 1.0", 0, 20+io)
cdisp(u8g2.font_profont17_mr, ip, 0, 40+io)
disp:sendBuffer()

-- Set up the gpio interrupt to catch pulses from the flowmeter

gpio.mode(flowMeterPin, gpio.INT)
gpio.trig(flowMeterPin, "up", gpioCB)

-- Preset pump speed to 0, set FWD direction

setPumpSpeed(0)
setPumpFwd()

-- See if the BLE module is alive

rsp=bleSPI.spi_command_check_OK("ATI")
print("rsp from ATI:")
print(ret)

if bleSPI.spi_connected() then print("connected") else print("not connected") end
print(" ")

-- Create the mainloop timer and callback

pumpTimer=tmr.create()
tmr.register(pumpTimer, 200, tmr.ALARM_SEMI, timerCB)
tmr.start(pumpTimer)

-- Create a watchdog in case the mainloop hangs

watchTimer=tmr.create()
tmr.register(watchTimer, 2000, tmr.ALARM_SINGLE, watchDog)
tmr.start(watchTimer)

