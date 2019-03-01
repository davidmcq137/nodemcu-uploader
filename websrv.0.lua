--[[

websrv.lua - a stupid-simple web server for the ESP8266 wifi subsystem

creates a server and listens on port 80

assumes a file websrv.html exists in the ESP flash file system. This file contains
the html and any required CSS/style elements for displaying a (very) simple website
on a remote browser. could work in sta or ap mode, envisioned more for ap mode using
a phone as a GUI conected to the 8266's AP for an iot project

the main idea is that the file websrv.html is stored in the flash file system, and thus the 
bulk of html data is kept out of RAM. the send() function reads the html file line-by-line
and uses the asynch style of completion functions to ensure that each line is sent to the server 
in order. If any line has a %d in it, it will be processed specially .. with the nth element
of the encode[] table inserted by doing a string encode. yes this is dirt simple and limited to one
encode per line, etc. It can be extended if needed. Or maybe the rest of the world has a simple
way do to this and I am just an idiot :-) done this way the websrv.lua and websrv.html must be kept
closely in synch regarding the content. concerns are not separated. but the footprint is small!

this advantage of doing it this way is that only one line at a time comes into RAM. the file is 
only opened once, and the file pointer is reset on each interaction. this is intended for VERY 
simple GUIs, e.g. on a phone browser with a few lines of info display and some buttons to control 
an iot device

--]]

local sendStr
local fileStr
local sendFile = false
local activeSend = false
local ff

local function sendCB(localSocket)
   if sendStr then -- string was sent, this is the callback
      sendStr = nil
      if not sendFile then
	 localSocket:close()
	 localSocket:on("sent", nil)
	 activeSend = false
	 --print("string sent:", sendStr)
      end
   end
   if sendFile then
      local ll = ff:readline()
      if ll then
	 localSocket:send(ll)
	 --print(ll)
      else
	 print("ll null -- EOF")
	 localSocket:close()
	 localSocket:on("sent", nil)
	 sendFile=false
	 activeSend=false
	 print("html file sent")
      end	 
   end
end

local function send(localSocket)
   if activeSend then
      print("?Already sending?")
   end
   localSocket:on("sent", sendCB)
   activeSend = true
   if sendStr then
      localSocket:send(sendStr)
   elseif sendFile then
      print("in sendFile")
      ff:seek("set", 0)
      print("sending:", fileStr)
      localSocket:send(fileStr)
   end
end

function receiver(client,request)
      
   --parse the response using lua patterns. I didn't think of this I stole it...
   --print("************************")
   --print("receiver: request:", request)
   
   local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
   --print("method, path,vars:", method, path, vars)

   if not method then
      _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
      --print("method nil: method, path:", method, path)
   end

   local parsedvar = {}

   if (vars ~= nil)then
      for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
	 parsedvar[k] = v
	 --print("k, v:", k, v)
      end
   end

   if path == "/" and not vars then
      print("sending html")
      sendFile = true
      send(client)
   elseif path == "/favicon.ico" then
      sendStr="HTTP/1.1 204 No Content"
      send(client)
   elseif path=="/" and vars then
   
      for k,v in pairs(parsedvar) do
	 --print("parsedvar loop: k,v=", k,v)
	 if k =="pumpSpeed" then
	    print("pumpSpeed=", v)
	 elseif k == "pressB" then
	    print("Button:", parsedvar[k])
	 end
      end

      -- package up responses here
      
      s1=tmr.time()
      s2=tmr.now()
      s3=node.heap()
      
      suffix=
	 string.format("%d,%d,%d", s1,s2,s3)
      prefix=
	 string.format("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n", #suffix)
      sendStr=prefix..suffix
      send(client)
   end
   
   
end

srv=net.createServer(net.TCP)
   
ff = file.open("websrv.html", "r")

local contentLength=0
while true do
   ll = ff:readline()
   if not ll then break end
   contentLength = contentLength + #ll
end


fileStr=string.format(
	 "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\n\r\n\r\n",
	 contentLength)

srv:listen(80,function(conn) conn:on("receive", receiver) end)

print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")

function startUp()
   dispTimer=tmr.create()
   tmr.register(dispTimer, 500, tmr.ALARM_SEMI, timerCB)
   --tmr.start(dispTimer)
end

dw=128
dh=64


function cdisp(font, text, x, y)
   local ww, xd
   --disp:setFont(font)
   ww=0--disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   --disp:drawStr(xd, y, text)
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
   
   --i2c.setup(0, sda, scl, i2c.SLOW)
   --disp = u8g2.ssd1306_i2c_128x64_noname(0, sla)
   
   --disp:setFontRefHeightExtendedText()
   --disp:setDrawColor(1)
   --disp:setFontPosTop()
   --disp:setFontDirection(0)
end

function pumpGoFwd()
   gpio.write(flowDirPin, gpio.LOW)
   pumpFwd=true
   --print("fwd")
end

function pumpGoRev()
   gpio.write(flowDirPin, gpio.HIGH)
   pumpFwd=false
   --print("rev")
end

pwmPumpPin = 8
flowDirPin =   3 --GPIO0
minPWM = 50
lastPWM = 0
pumpStartTime = 0
pumpStopTime = 0
pump_pwm = 0

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
      if pumpSpeed < -100 then
	 pumpSpeed = -100
      end
      if pumpSpeed > 100  then
	 pumpSpeed = 100
      end
      if pumpSpeed >= 0 then
	 pumpGoFwd()
      else
	 pumpGoRev()
      end
      lastPos = pos
   end

   if type == rotary.DBLCLICK then
      saveCount = pulseCount 
   end

   if type == rotary.LONGPRESS then
      pulseCount = 0
      lastPulseCount=0
      flowRate=0
      pumpStartTime=0
      pumpStopTime=0
   end

   if type == rotary.PRESS then
      pumpSpeed = 0
   end
   pump_pwm = math.floor(math.abs(pumpSpeed*1023/100))
   if pump_pwm < minPWM then pump_pwm = 0 end
   --print("pwm:", pump_pwm)
   pwm.setduty(pwmPumpPin, pump_pwm)

   if lastPWM == 0 and pump_pwm > 0 then -- just turned on .. note start time
      pumpStartTime = tmr.time()
   end
   if lastPWM > 0 and pump_pwm == 0 then -- just turned off .. note stop time
      pumpStopTime = tmr.time()
   end
   
      
   lastTime = time
   lastPWM = pump_pwm
end

flowMeterPin = 7 --GPIO13

function gpioCB(lev, pul, cnt)
   if pumpFwd then
      pulseCount=pulseCount + cnt
   else
      pulseCount=pulseCount - cnt
   end
   
   gpio.trig(flowMeterPin, "up")
end

function timerCB()
   --print("timerCB")
   local now = tmr.now()
   local deltaT = math.abs(math.abs(now) - math.abs(lastFlowTime)) / (1000000. * 60.) -- mins
   lastFlowTime = now
   local deltaF = (pulseCount - lastPulseCount) / pulsePerOz
   lastPulseCount = pulseCount
   flowRate = flowRate - (flowRate - (deltaF / deltaT))/4
   --if flowRate < 0 then flowRate = 0 end -- handle correctly in rotary button callback
   local io=2
   --disp:clearBuffer()

   if pump_pwm > 0 then
      runningTime = math.abs(math.abs(tmr.time()) - math.abs(pumpStartTime))
   else
      runningTime = math.abs(math.abs(pumpStopTime) - math.abs(pumpStartTime))
   end
   local rt = math.min(runningTime)
   --cdisp(u8g2.font_profont17_mr, string.format("Vol %.1f oz",   pulseCount/pulsePerOz), 1,  0+io)
   if runningTime <= 59 then
      --cdisp(u8g2.font_profont17_mr, string.format("Tim %2d sec",  math.floor(rt)), 1, 15+io)
   else
      local min = math.floor(rt/60)
      local sec = math.floor(rt-60*min)
      --cdisp(u8g2.font_profont17_mr, string.format("Tim %2d:%02d min",  min, sec), 1, 15+io)
   end

   tickTock = tmr.time()
   if tickTock%6 < 3 and pump_pwm > minPWM then
      --cdisp(u8g2.font_profont17_mr, string.format("Flw %.1f oz/m", flowRate), 1, 30+io)
   else
      --cdisp(u8g2.font_profont17_mr, string.format("P   %.1f psi", 1.2),       1, 30+io)
   end
   
   --cdisp(u8g2.font_6x10_tf, "Empty", 20, 53)
   --cdisp(u8g2.font_6x10_tf, "Fill",  85, 53)

   --disp:drawFrame(1, 52, 127, 12)
   --local j = math.floor(63*minPWM/1023)
   ----disp:drawFrame(64-j, 52, 2*j, 12)
   local k = math.floor( (pumpSpeed/100)*63)
   if pumpSpeed >= 0 then
      --disp:drawBox(64, 52, k, 12)
   else
      --disp:drawBox(64+k, 52, -k, 12)      
   end
   --disp:drawVLine(64,52,12)
   --disp:sendBuffer()
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
pulsePerOz=77.6
pumpSpeed = 0
flowRate=0
pumpFwd=true

--rotary.setup(0,2,1,4, 1000, 500) -- GPIO4,GPIO5,GPIO2

--rotary.on(0, rotary.ALL, rotaryCB)

pwm.setup(pwmPumpPin, 1000, 0) -- GPIO15, 1Khz, 0% duty cycle

gpio.mode(flowDirPin, gpio.OUTPUT)
gpio.write(flowDirPin, gpio.LOW)

gpio.mode(flowMeterPin, gpio.INT)

pulseCount=0

gpio.trig(flowMeterPin, "up", gpioCB)

--init_i2c_display() -- uses (5,6) GPIO14,GPIO12 

--disp:clearBuffer()

io=2
--cdisp(u8g2.font_profont22_mr, "MedidoPump", 0, 0+io)
--cdisp(u8g2.font_profont17_mr, "Version 1.0", 0, 25+io)
--disp:sendBuffer()

splashTimer=tmr.create()
tmr.register(splashTimer, 4000, tmr.ALARM_SINGLE, startUp)
--tmr.start(splashTimer)
