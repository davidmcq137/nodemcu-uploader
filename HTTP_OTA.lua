--
-- If you have the LFS _init loaded then you invoke the provision by 
-- executing LFS.HTTP_OTA('your server','directory','image name').  Note
-- that is unencrypted and unsigned. But the loader does validate that
-- the image file is a valid and complete LFS image before loading.
--
-- http://dl.dropboxusercontent.com/s/3az2gndokyvbw2o/LFS.img?dl=0
--
local host, dir, image = "10.0.0.48", "/", "HLFS.img"
-- local host, dir, image = "prism-spectacles.s3.amazonaws.com", "/", "LFS.img"
-- local host, dir, image = "github.com", "/davidmcq137/nodemcu-uploader/blob/scale", "LFS.img"

local hostsocket = 8080
local doRequest, firstRec, subsRec, finalise
local n, total, size = 0, 0
  
doRequest = function(sk,hostIP)
   if not wifi.sta.getip() then
      print("No WiFi connection")
      return
   end
   if hostIP then 
      local con = net.createConnection(net.TCP,0)
      con:connect(hostsocket, hostIP)
      -- Note that the current dev version can only accept uncompressed LFS images
      con:on("connection",function(sck)
		local request = table.concat( {
		      "GET "..dir..image.." HTTP/1.1",
		      "User-Agent: ESP8266 app (linux-gnu)",
		      "Accept: application/octet-stream",
		      "Accept-Encoding: identity",
		      "Host: "..host,
		      "Connection: close", 
		      "", "", }, "\r\n")
		print("request:" .. request)
		sck:send(request)
		sck:on("receive",firstRec)
      end)
   else
      print("Cannot connect to host. hostIP:", hostIP)
   end
end

firstRec = function (sck,rec)
   -- Process the headers; only interested in content length
   print("rec:", rec)
   if #rec == 0 then
      sck:on("receive", nil)
      sck:close()
      print("GET failed - never saw Content-Length in header")
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
      print("about to open", image)
      file.open(image, 'w')
      subsRec(sck, rec:sub(i+4))
   else
      sck:on("receive", nil)
      sck:close()
      print("GET failed, can't compute file size from header")
   end
end 

subsRec = function(sck,rec)
  total, n = total + #rec, n + 1
  if n % 4 == 1 then
    sck:hold()
    node.task.post(0, function() sck:unhold() end)
  end
  uart.write(0,('%u of %u, '):format(total, size))
  file.write(rec)
  if total == size then finalise(sck) end
end

finalise = function(sck)
   file.close()
   print("file closed")
  sck:on("receive", nil)
  sck:close()
  local s = file.stat(image)
  print("image:", image)
  print("stat returns:", s)
  if (s and size == s.size) then
    wifi.setmode(wifi.NULLMODE)
    collectgarbage();collectgarbage()
    -- run as separate task to maximise RAM available
    print("")
    print("Preparing to flashreload:", image)
    node.task.post(function() node.flashreload(image) end)
  else
     print("Invalid save of image file")
  end
end

print("WiFi OTA Start with host, socket=", host, hostsocket)
print("image to be reloaded=", image)
print("1.0")
print("2.0")
print("3.0")

--print("medidoEnabled:", medidoEnabled)
medidoEnabled = false



--net.dns.resolve(host, doRequest)


----------

print('First init WiFi Station')
--
function wifiIPcallback(T)
   print("\n\t**Callback: STA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
	    T.netmask.."\n\tGateway IP: "..T.gateway)
   --print("calling start.lua")
   -- this next line will start the ota update
   print("calling net.dns.resolve to start OTA transfer")
   net.dns.resolve(host, doRequest)   
   --tmr.alarm(0, 100, tmr.ALARM_SINGLE, function() dofile("start.lua") end)
end
--
wifi.setmode(wifi.STATION)
print('set mode=STATION (mode='..wifi.getmode()..')')
print('MAC: ',wifi.sta.getmac())
print('chip: ',node.chipid())
print('heap: ',node.heap())
--
--wifi.setphymode(wifi.PHYMODE_B)
--wifi.setcountry({country="US", start_ch=1, end_ch=12, policy=wifi.COUNTRY_AUTO})
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifiIPcallback)
--
-- wifi config start
local config_tbl={}
config_tbl.ssid="Mt McQueeney Guest"
config_tbl.pwd="south18ln"
--config_tbl.ssid="McQphone"
--config_tbl.pwd="Hydro137Ponic"
config_tbl.save=true
config_tbl.auto=true
--
print("Attempting connection to AP:", config_tbl.ssid)
wifi.sta.config(config_tbl)
--
function listap(t) -- (SSID : Authmode, RSSI, BSSID, Channel)
    print("\n\t\t\tSSID\t\t\t\t\tBSSID\t\t\t  RSSI\t\tAUTHMODE\t\tCHANNEL")
    for bssid,v in pairs(t) do
        local ssid, rssi, authmode, channel = string.match(v, "([^,]+),([^,]+),([^,]+),([^,]*)")
        print(string.format("%32s",ssid).."\t"..bssid.."\t  "..rssi.."\t\t"..authmode.."\t\t\t"..channel)
    end
end
--
local config_scan={}
config_scan.ssid=nil
config_scan.bssid=nil
config_scan.channel=0
config_scan.show_hidden=1
--
--wifi.sta.getap(config_scan, 1, listap)
--wifi.sta.getap(1, listap)
-- wifi config end
