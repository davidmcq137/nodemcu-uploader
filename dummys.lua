do
   local a=debug.getstrings'RAM'
   for i=1, #a do a[i] = ('%q'):format(a[i]) end
   print('local preload='..table.concat(a,','))
end

--[[

local preload="","\
        Callback: STA - GOT IP","\
        Gateway IP: ","\
        Station IP: ","\
        Subnet mask: ","\r\
","%d","%f,%f,%f,%f,%f,%f","%q","(%w+)=(%w+)&*","([A-Z]+) (.+) HTTP","([A-Z]+) (                                        .+)?(.+) HTTP",",",".gz","/","/\
;\
?\
!\
-","/(.*)","/Poll","15","200 OK","=stdin","?.lc;?.lua","@./espWebServer.lua","@.                                        /medido.lua","@dummys.lua","@init.lua","Attempt to command before calFact - reje                                        cted:","Clear","Content-Encoding: ","Content-length: ","Content-type: ","ESP8266                                        ","File loaded, time (ms):","Fwd","HIGH","HTTP/1.1 ","HTTP/1.1 200 OK\
Content-Type: text/plain\
Content-Length: %d\
\
","HTTP/1.1 204 No Content\r\
\r\
","Heap:","IP","Keep-Alive: Timeout=","LOW","Lua 5.1","Mt McQueeney Guest","No f                                        ile: ","No mime type for fileType ","PWM set to:","RAM","Rev","Server: ","TCP","                                        [^.]+$","[^/]+$","_G","_LOADED","_LOADLIB","_VERSION","__add","__call","__concat                                        ","__div","__eq","__gc","__index","__le","__len","__lt","__mod","__mode","__mul"                                        ,"__newindex","__pow","__sub","__unm","abs","adc","alive","audio/mpeg","buildHtt                                        pHeader","cF","calFact passed in:","close","collectgarbage","concat","config","c                                        onfig_tbl","cpath","createServer","css","debug","dofile","dummys.lua","encoding"                                        ,"espWebServer","exists","file","file.obj","file.vol","fileName","filePointer","                                        filePrefix","find","floor","format","fp","gateway","getstrings","gmatch","gpio",                                        "gpioCB","gzip","heap","html","http","ico","identity","idx","idx error:","image/                                        x-icon","index.html","ipairs","ipcallback","js","kv","length","listen","loadStar                                        t","loaded","loaders","loadlib","local preload=","match","math","module","mp3","                                        net","net.tcpserver","net.tcpsocket","net.udpsocket","netmask","newproxy","node"                                        ,"not enough memory","now","on","open","pB","pC","pS","package","pairs","panic:                                         fp nil","path","path, filePath:","prefix","preload","print","pump start","pump s                                        top","pumpTimer","pwd","pwm","r","read","receive","receiver","require","save","s                                        aveTable","seeall","send","sendFile","sendOneString","sendStr","sent","seq","ser                                        ver","setAjaxCB","setduty","size","sjson.decoder","sjson.encoder","sndFileCB","s                                        ndStrCB","south18ln","ssid","start","stat","string","table","text/css","text/htm                                        l","text/javascript","timerCB","tmr","tmr.timer","tonumber","trig","type","u8g2.                                        display","up","write","xhrCB"





--]]
