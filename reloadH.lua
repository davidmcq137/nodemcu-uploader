print("Re-loading flash with HLFS.img in 1 sec")
tmr.create():alarm(1000, tmr.ALARM_SINGLE, function() node.flashreload("HLFS.img") end)
