--[[

espWebServer.lua

a very small footprint HTTP server for use in the nodemcu environment

set up as a lua module so you can do:

eWS = require "espWebServer"

two external function calls:

espWebServer.setAjaxCB() -- call this one with a callback function for each query string
espWebServer.start()     -- call this one to set port and buffer size and start the server

restrictions: 

only implements one route: "/" for index.html and other source(s) and ajax with query strings
only intended for GET requests

oddness: sometimes loads files twice??

--]]

local espWebServer = {}

local fileHeader
fileHeader = {
   http="HTTP/1.1 ",
   type="Content-type: ",
   length="Content-length: ",
   alive="Keep-Alive: Timeout=",
   server="Server: ",
   encoding="Content-Encoding: ",
}

local mimeType
mimeType = {
   html = "text/html",
   css  = "text/css",
   js   = "text/javascript",
   ico  = "image/x-icon",
   mp3  = "audio/mpeg",
}

local stringHeader
stringHeader =
[[
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: %d

]]

local cbFunction
local bufsize
local sockDrawer={}

function espWebServer.setAjaxCB(functionName)
   -- callback function. called with argument = parsed variable (lua) table from GET's query string
   -- user should return the string that will be the content payload of the HTTP GET request
   cbFunction = functionName
   return
end

function espWebServer.start(port, bs)
   local srv=net.createServer(net.TCP)
   bufsize = bs
   srv:listen(port,function(conn) conn:on("receive", receiver) end)
   return srv
end

function sndStrCB(sock)
   sock:on("sent", nil)
   sock:close()
end

local isk=0
local sendTimer

function sndFileCB(sock)
   --print("in sndFileCB - ", tmr.state(sendTimer) )
   local running, tmode = tmr.state(sendTimer)
   if not running or tmode ~= 0 then
      print("bad tmr.state()", running, tmode)
   end
   local fp = sockDrawer[sock].filePointer
   local ll = fp:read(bufsize)
   if ll then sock:send(ll) else
      local fn = sockDrawer[sock].fileName
      local ls = sockDrawer[sock].loadStart
      --print("CB closes:", fn)
      tmr.stop(sendTimer) -- kill watchdog
      sockDrawer[sock] = nil
      fp:close()
      sock:close()
      isk = isk - 1
      print("File loaded, time (ms):", fn, (tmr.now()-ls)/1000., isk)
      -- local iii=0
      -- for k,v in pairs(sockDrawer) do
      -- 	 iii = iii + 1
      -- 	 print("Entry:", iii)
      -- 	 print("sD{} key:", k)
      -- 	 print("sD{}.fileName", v.fileName)
      -- 	 print("sD{}.filePointer", v.filePointer)
      -- 	 print("sD{}.file.loadStart", v.loadStart)	 
      -- end
      for k,v in pairs(sockDrawer) do
	 if v.filePointer == 0 then
	    fp = file.open(v.fileName, "r")
	    if not fp then
	       print("panic: fp nil")
	       return
	    end
	    v.filePointer=fp
	    k:on("sent", sndFileCB)
	    sendTimer=tmr.create()
	    tmr.register(sendTimer, 5000, tmr.ALARM_SINGLE, watchDog)
	    tmr.start(sendTimer)
	    k:send(v.filePrefix)
	    break
	 end
      end
      collectgarbage()
   end
end

function buildHttpHeader(size, mime, enc)
   local crlf = "\r\n"
   local ch = fileHeader.http.."200 OK"
   local cl = string.format(fileHeader.length.."%d", size)
   local ct = fileHeader.type..mime
   local ck = fileHeader.alive.."15"
   local cs = fileHeader.server.."ESP8266"
   local ce = fileHeader.encoding..enc
   return ch..crlf..ct..crlf..cl..crlf..ck..crlf..cs..crlf..ce..crlf..crlf
end

function watchDog(T)
   print("*** watchdog executed ***", T)
end

function sendFile(fn, mimetype, sock, enc)
   local fs = file.stat(fn)
   if not fs then return nil end
   local pp = buildHttpHeader(fs.size, mimetype, enc)
   if isk > 0 then
      fp = 0
   else
      fp = file.open(fn, "r")
      if not fp then return nil end
   end
   isk = isk + 1
   sockDrawer[sock] = {fileName=fn, filePointer=fp, filePrefix=pp, loadStart=tmr.now()}
   if fp ~= 0 then
      sock:on("sent", sndFileCB)
      -- set up watchdog timer 5s
      sendTimer=tmr.create()
      tmr.register(sendTimer, 5000, tmr.ALARM_SINGLE, watchDog)
      tmr.start(sendTimer)
      sock:send(pp)
   end
   return true
end

function sendOneString(str, sock)
   sock:on("sent", sndStrCB)
   sock:send(str)
end

function receiver(client,request)

   if not medidoEnabled then return end
   
   local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
   if not method then
      _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
   end
   --
   -- print("client", client)
   -- print("path", path)
   -- print("vars", vars)
   -- print("request",request)
   -- print("method", method)
   
   local parsedVariables = {}
   if vars then
      for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
	 parsedVariables[k] = v
      end
   end

   local sendStr
   
   if path=="/Poll" then
      local prefix, suffix
      if cbFunction then
	 suffix = cbFunction(parsedVariables)
      end
      prefix = string.format(stringHeader, #suffix)
      sendStr = prefix..suffix
      sendOneString(sendStr, client)
      return
   end

   local fileType, filePath, fileName
   
   if path == '/' then
      filePath = "index.html"
      fileType = "html"
   else
      fileName = string.match(path, "[^/]+$")
      fileType = string.match(path, "[^.]+$")
      filePath = string.match(path, "/(.*)")
   end

   --print("path, filePath:", path, filePath)
   
   local mime = mimeType[fileType]

   if not mime then
      mime = "text/html" -- dunno
      if path ~= '/' then
	 print("No mime type for fileType ", fileType)
      end
   end

   local contEnc = nil
   local sendPath = filePath..".gz"
   if file.exists(sendPath) then
      contEnc = "gzip"
   elseif file.exists(filePath) then
      contEnc = "identity"
      sendPath = filePath
   end
   if contEnc then
      sendFile(sendPath, mime, client, contEnc)
      return
   else
      sendStr="HTTP/1.1 204 No Content\r\n\r\n"
      print("No file: "..filePath)
      sendOneString(sendStr, client)
      return      
   end
end

return espWebServer
