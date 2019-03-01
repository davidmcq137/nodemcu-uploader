print("Re-loading flash with lfs.img in 1 sec")
tmr.alarm(0, 1000, tmr.ALARM_SINGLE, 
	  function()
	     node.flashreload("lfs.img")
end)

