--
-- <Original comment unedited>
-- If you have the LFS _init loaded then you invoke the provision by 
-- executing LFS.HTTP_OTA('your server','directory','image name').  Note
-- that is unencrypted and unsigned. But the loader does validate that
-- the image file is a valid and complete LFS image before loading.
--

local httpOTA = {}


local host, dir, image = "10.0.0.48", "/", "HLFS.img"
local hostsocket = 8080

local uPrt, doRequest, firstRec, subsRec, finalise
local n, total, size = 0, 0
local wifiTimeout
local webTimeout



uPrt = function(n)
  uart.write(0,('(OTA:%d)'):format(n))   
end

doRequest = function(sk,hostIP)
   if not wifi.sta.getip() then
      uPrt(-1)
      --print("No WiFi connection")
      return
   end
   if hostIP then 
      uPrt(3)
      local con = net.createConnection(net.TCP,0)
      con:connect(hostsocket, hostIP)
      con:on("connection",function(sck)
		local request = table.concat( {
		      "GET "..dir..image.." HTTP/1.1",
		      "User-Agent: ESP8266 app (linux-gnu)",
		      "Accept: application/octet-stream",
		      "Accept-Encoding: identity",
		      "Host: "..host,
		      "Connection: close", 
		      "", "", }, "\r\n")
		--print("request:" .. request)
		sck:send(request)
		sck:on("receive",firstRec)
      end)
   else
      uPrt(-2)
      --print("Cannot connect to host. hostIP:", hostIP)
   end
end

firstRec = function (sck,rec)
   -- Process the headers; only interested in content length
   print("rec:", rec)
   if #rec == 0 then
      sck:on("receive", nil)
      sck:close()
      uPrt(-3)
      --print("GET failed - never saw Content-Length in header")
      return
   end
   local i = rec:find('\r\n\r\n',1,true)

   if i==nil then -- have not seen content length yet
      sck:on("receive", firstRec) -- keep reading rest of header
      return
   end
   local header = rec:sub(1,i+1):lower()

   size = tonumber(header:match('\ncontent%-length: *(%d+)\r') or 0)

   if size > 0 then
      sck:on("receive",subsRec)
      --print("about to open", image)
      file.open(image, 'w')
      subsRec(sck, rec:sub(i+4))
   else
      sck:on("receive", nil)
      sck:close()
      uPrt(-4)
      --print("GET failed, can't compute file size from header")
   end
end 

subsRec = function(sck,rec)
  total, n = total + #rec, n + 1
  if n % 4 == 1 then
    sck:hold()
    node.task.post(0, function() sck:unhold() end)
  end
  uart.write(0,('%u of %u, '):format(total, size))
  uPrt(math.floor(100*total / size))
  file.write(rec)
  if total == size then finalise(sck) end
end

finalise = function(sck)
   file.close()
   --print("file closed")
   sck:on("receive", nil)
   sck:close()
   local s = file.stat(image)
   --print("image:", image)
   --print("stat returns:", s)
   if (s and size == s.size) then
      wifi.setmode(wifi.NULLMODE)
      collectgarbage();collectgarbage()
      -- run as separate task to maximise RAM available
      --print("")
      --print("Preparing to flashreload:", image)
      tmr.unregister(webTimeout) -- kill timeout timer for web
      node.task.post(function() node.flashreload(image) end)
   else
      uPrt(-5)
      --print("Invalid save of image file")
   end
end

function webCB(T)
   --gets here if web req never completed
   uPrt(-7)
end

function wifiIPcallback(T)
   --print("\n\t**Callback: STA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
   -- 	    T.netmask.."\n\tGateway IP: "..T.gateway)
   -- this next line will start the ota update
   --print("calling net.dns.resolve to start OTA transfer")
   tmr.unregister(wifiTimeout) -- kill timeout timer for wifi
 
   webTimeout=tmr.create() -- create one for the web interaction
   tmr.register(webTimeout, 10000, tmr.ALARM_SINGLE, webCB)
   tmr.start(webTimeout)

   uPrt(2)
   net.dns.resolve(host, doRequest)   
end


function wifiCB(T)
   --gets here if wifi never connected
   uPrt(-6)
end


function httpOTA.OTAstart(wt)

   --https://medido-updates.s3.us-east-2.amazonaws.com/MedP.img
   --local host, dir, image = "prism-spectacles.s3.amazonaws.com", "/", "LFS.img"
   --host = "medido-updates.s3.us-east-2.amazonaws.com"
   --host = "medido-pump.s3.us-east.cloud-object-storage.appdomain.cloud"

   image = wt.image
   host = wt.host
   hostsocket = wt.socket
   --hostsocket = 80 -- don't forget to chg this .. local usually on 8080
   dir = wt.dir

   wifi.setmode(wifi.STATION)
   uPrt(1)
   wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifiIPcallback)
   
   -- wifi config start

   local config_tbl={}
   config_tbl.ssid=wt.ssid
   config_tbl.pwd=wt.pwd
   config_tbl.save=true
   config_tbl.auto=true
   wifi.sta.config(config_tbl)
   
   --create 10s watchdog to warn if wifi never connected
   
   wifiTimeout=tmr.create()
   tmr.register(wifiTimeout, 10000, tmr.ALARM_SINGLE, wifiCB)
   tmr.start(wifiTimeout)



end

local arg = {...}


foo = function (bar)
   print("in foo. bar:", bar)
end

-- called here on startup with arg[1] = "httpOTA"

print(#arg)
for i=1,#arg,1 do
   print(i, arg[i])
end

if arg[1] == "test" then
   foo("hi there")
end


return httpOTA
