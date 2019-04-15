--
-- If you have the LFS _init loaded then you invoke the provision by 
-- executing LFS.HTTP_OTA('your server','directory','image name').  Note
-- that is unencrypted and unsigned. But the loader does validate that
-- the image file is a valid and complete LFS image before loading.
--

local host, dir, image = "10.0.0.48", "/", "lfs.img"
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
		print(request)
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
  sck:on("receive", nil)
  sck:close()
  local s = file.stat(image)
  if (s and size == s.size) then
    wifi.setmode(wifi.NULLMODE)
    collectgarbage();collectgarbage()
    -- run as separate task to maximise RAM available
    print("")
    print("Preparing to flashreload:", image)
    node.task.post(function() node.flashreload(image) end)
  else
    print"Invalid save of image file"
  end
end

print("WiFi OTA Start with host, socket=", host, hostsocket)
print("medidoEnabled:", medidoEnabled)
medidoEnabled = false

net.dns.resolve(host, doRequest)
