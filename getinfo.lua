print("IP address: ", wifi.sta.getip())

do
  for k,v in pairs(wifi.sta.getapinfo()) do
    if (type(v)=="table") then
      print(" "..k.." : "..type(v))
      for k,v in pairs(v) do
        print("\t\t"..k.." : "..v)
      end
    else
      print(" "..k.." : "..v)
    end
  end
end

--print stored access point info(formatted)
do
  local x=wifi.sta.getapinfo()
  local y=wifi.sta.getapindex()
  print("\n Number of APs stored in flash:", x.qty)
  print(string.format("  %-6s %-32s %-64s %-18s", "index:", "SSID:", "Password:", "BSSID:")) 
  for i=1, (x.qty), 1 do
    print(string.format(" %s%-6d %-32s %-64s %-18s",(i==y and ">" or " "), i, x[i].ssid, x[i].pwd and x[i].pwd or type(nil), x[i].bssid and x[i].bssid or type(nil)))
  end
end
