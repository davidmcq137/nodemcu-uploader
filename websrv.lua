--[[

medido pump

--]]

flowDirPin   = 3 --GPIO0
flowMeterPin = 7 --GPIO13
pwmPumpPin   = 8 --GPIOxx

pulseCount=0
flowRate=0
lastPulseCount=0
lastFlowTime=0
pulsePerOz=77.6

minPWM = 50
maxPWM = 1023
lastPWM = 0
pumpPWM = 0

pumpFwd=true

pumpStartTime = 0
pumpStopTime = 0
runningTime = 0

pulseCount = 0
flowCount  = 0

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
   print("pwm set to:", pumpPWM)
   lastPWM = pumpPWM
end

function setPumpFwd()
   gpio.write(flowDirPin, gpio.LOW)
   pumpFwd=true
   print("Fwd")
end

function setPumpRev()
   gpio.write(flowDirPin, gpio.HIGH)
   pumpFwd=false
   print("Rev")
end

function timerCB()
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
   tmr.start(pumpTimer)
end

pwm.setup (pwmPumpPin,   1000, 0)         

gpio.mode (flowDirPin,   gpio.OUTPUT)
gpio.write(flowDirPin,   gpio.LOW)

gpio.mode (flowMeterPin, gpio.INT)
gpio.trig (flowMeterPin, "up", gpioCB)

pumpTimer=tmr.create()
tmr.register(pumpTimer, 200, tmr.ALARM_SEMI, timerCB)
tmr.start(pumpTimer)


----------------------------------------------------------------------------------------------------

fileHeader =
[[
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: %d
Connection: keep-alive
Keep-Alive: timeout=15
Accept-Ranges: bytes
Server: ESP8266

]]

stringHeader=
[[
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: %d

]]

local sockDrawer={}
local loadStart

function sndStrCB(sock)
   sock:on("sent", nil)
   sock:close()
end

lc = 0

function sndFileCB(sock)
   local fp = sockDrawer[sock].filePointer
   local fn = sockDrawer[sock].fileName
   local ll = fp:readline()
   if ll then
      sock:send(ll)
      lc = lc + 1
      if lc % 100 == 0 then
	 print("lc", lc)
	 print("heap:", node.heap())
      end
   else
      print("closing file and socket:", fn, sock)
      print("file loaded, time (ms):", fn, (tmr.now()-loadStart)/1000.)
      fp:close()
      sock:close()
      sockDrawer[sock] = nil
   end
end

function sendFile(fn, prefix, sock)
   local fs = file.stat(fn)
   if not fs then return nil end
   print("opening file, sock", fn, sock)
   local fp = file.open(fn, "r")
   if not fp then return nil end
   local pp = string.format(prefix, fs.size)
   sockDrawer[sock] = {fileName=fn, filePointer=fp, filePrefix=pp}
   print("added to sD, sock #sD:", sock, #sockDrawer)
   if not loadStart then loadStart = tmr.now() end
   sock:on("sent", sndFileCB)
   sock:send(sockDrawer[sock].filePrefix)
   return true
end

function sendOneString(str, sock)
   sock:on("sent", sndStrCB)
   sock:send(str)
end

local lastSpeed = 0

function receiver(client,request)
      
   print("************************")   
   print("client:", client)
   print("************************")
   --print("receiver: request, time:", tmr.now()/1000000)
   print(request)
   print("*****************")
   
   --parse the response using lua patterns. I didn't think of this I stole it...

   local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
   --print("method, path,vars:", method, path, vars)

   if not method then
      _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
      --print("method nil: method, path:", method, path)
   end

   local parsedvar = {}

   if vars then
      for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
	 parsedvar[k] = v
      end
   end
   
   if (string.find(path, "/") == 1)  and not vars then
      local filename=string.match(path, "/(.*)")
      print("filename:", string.format("**%s**", filename))
      if #filename == 0 or filename == '' then
	 filename = "websrv.html"
      end
      if file.exists(filename) then
	 print("calling sendFile with", filename)
	 sendFile(filename, fileHeader, client)
	 return
      else
	 sendStr="HTTP/1.1 204 No Content\r\n"
	 print("No file: "..sendStr)
	 sendOneString(sendStr, client)
	 return
      end
      
   end

   -- should never get here with a file loading, thus...
   
   if #sockDrawer > 0 then
      print("Please meet dfm at the suspension bridge")
      print("method, path, vars:", method, path, vars)
      return
   end
      
   if path=="/" and vars then
   
      for k,v in pairs(parsedvar) do
	 --print("parsedvar loop: k,v=", k,v)
	 if k =="pumpSpeed" then
	    --print("pumpSpeed=", v)
	    ps = tonumber(v)
	    if ps ~= lastSpeed then
	       setPumpSpeed(ps)
	       lastSpeed = ps
	    end
	 elseif k == "pressB" then
	    --print("Button:", parsedvar[k])
	    pb = tonumber(v)
	    if pb == 1 then
	       setPumpFwd()
	    elseif pb == 2 then
	       setPumpSpeed(0)
	       lastSpeed = ps
	    elseif pb == 3 then
	       setPumpRev()
	    end
	 end
      end

      -- package up responses here
      
      s0=node.heap()
      s1=flowCount
      s2=flowRate
      s3=runningTime
      
      suffix = string.format("%f,%f,%f,%f", s0,s1,s2,s3)
      prefix = string.format(stringHeader, #suffix)
      sendStr = prefix..suffix
      print("sendStr:", sendStr)
      sendOneString(sendStr, client)
   end
end

srv=net.createServer(net.TCP)

print("Starting receiver on port 80")

srv:listen(80,function(conn) conn:on("receive", receiver) end)


-------------------------------------------------------------------------------------------------
