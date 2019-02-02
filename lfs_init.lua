if node.flashindex() == nil then 
  node.flashreload('lfs.img') 
end
print("about to timer")
tmr.alarm(0, 5000, tmr.ALARM_SINGLE, 
	  function()
	     dofile("_init.lua")
end)
print("5 secs to do tmr.stop(0) before _init.lua")
