function wifiIPcallback(T)
   print("\n\tCallback: STA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
	    T.netmask.."\n\tGateway IP: "..T.gateway)
   print("calling start.lua")
   tmr.alarm(0, 100, tmr.ALARM_SINGLE, function() dofile("start.lua") end)
end

print('init.lua for WiFi Station')
wifi.setmode(wifi.STATION)
print('set mode=STATION (mode='..wifi.getmode()..')')
print('MAC: ',wifi.sta.getmac())
print('chip: ',node.chipid())
print('heap: ',node.heap())

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, wifiIPcallback)

-- wifi config start
local config_tbl={}
config_tbl.ssid="Mt McQueeney Guest"
config_tbl.pwd="south18ln"
config_tbl.save=true
print("Attempting connection to AP:", config_tbl.ssid)
wifi.sta.config(config_tbl)
-- wifi config end
