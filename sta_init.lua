print('init.lua for WiFi Station')
--
function wifiIPcallback(T)
   print("\n\tCallback: STA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
	    T.netmask.."\n\tGateway IP: "..T.gateway)
   print("calling start.lua")
   tmr.alarm(0, 100, tmr.ALARM_SINGLE, function() dofile("start.lua") end)
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
wifi.sta.getap(1, listap)
-- wifi config end
