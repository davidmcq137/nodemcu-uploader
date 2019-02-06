print("init.lua")
print("fi:", node.flashindex())
flashFile="lfs.img"
if not file.exists(flashFile) then
   print("Cannot find "..flashFile)
   return
end

if node.flashindex() == nil then 
   print("flashindex is nil, reloading .."..flashFile)
   node.flashreload(flashFile) 
end
tmr.alarm(0, 5000, tmr.ALARM_SINGLE, 
	  function()
	     dofile("_init.lua")
end)
print("5 secs to do tmr.stop(0) before _init.lua")
