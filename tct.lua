local now, deltaT, dtus
local lastFlowTime = 0

--print("starting", tmr.now())

local ii = 0

repeat
   ii = ii + 1
   if ii > 100000 then
      print(ii, tmr.now(), 2^31 - tmr.now(), tmr.time())
      if tmr.now() < 0 then
	 print("<0")
	 exit()
      end
      
      ii = 0
      tmr.wdclr()
   end
 until false
