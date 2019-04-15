local slotsRunning = false
local slotsTimer
local slotsInterval
local slotsDigit
local slotsTimeout = 2000
local slotsStart = 10
local slotsMult = 1.2

function digout(dig)
   for i=0,3,1 do
      if bit.isset(dig, i) then
	 gpio.write(i+1, 1)
      else
	 gpio.write(i+1, 0)
      end
   end
end

function tmrcb()

   sec, usec, rate = rtctime.get()
   if sec == 0 then
      print("sec=0")
      return
   end
   print("tmrcb: sec, usec, rate", sec, usec, rate)
   tm = rtctime.epoch2cal(sec-4*60*60)
   
   print(string.format("%04d/%02d/%02d %02d:%02d:%02d",
		       tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
   local secOnes = tm.sec % 10
   
   print("sec ones:", secOnes)

   if tm.sec == 50 then
      slotsRunning = true
      slotsInterval = slotsStart
      slotsDigit = 9
      tmr.interval(slotsTimer, slotsInterval) -- start at slotsStart msec then slow down from there
      tmr.start(slotsTimer)
   end
   

   if not slotsRunning then digout(tm["sec"]%10) end

end

function slotsCB()
   print("slotsCB", slotsDigit, slotsInterval)
   digout(slotsDigit)
   slotsDigit = slotsDigit - 1
   if slotsDigit < 0 then slotsDigit = 9 end
   slotsInterval = slotsInterval * slotsMult
   if slotsInterval < slotsTimeout then
      tmr.interval(slotsTimer, slotsInterval)
      tmr.start(slotsTimer)
   else
      slotsRunning = false
   end
end


function ntpcb(offset_s, offset_us, server, info)
   print("synch!", offset_s, offset_us, server)
   print("info", info.offset_s, info.offset_us, info.delay_us, info.stratum, info.leap)
end

function errntpcb(ierr, errstr)
   print("Err on synch", ierr, errstr)
end

for i=1,4,1 do
   gpio.mode(i, gpio.OUTPUT)
end

print("about to sntp.synch")

sntp.sync(nil, ntpcb, errntpcb, 1)

print("back from sntp.synch")

if not tmr.create():alarm(1000, tmr.ALARM_AUTO, tmrcb) then
   print("error setting up timer")
end

slotsTimer = tmr.create()
slotsInterval = 100 -- msec
tmr.register(slotsTimer, slotsInterval, tmr.ALARM_SEMI, slotsCB)



