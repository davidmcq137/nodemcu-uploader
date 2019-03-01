function delay()
   if swireset then
      switec.reset(0)
      swireset = false
   end
   local movtimer=tmr.create()
   movtimer:register(200, tmr.ALARM_SINGLE, weigh)
   movtimer:start()
end

function weigh(t)

   -- weight() intended only to be called from delay()

   if t ~= nil then t:unregister() end
      
   local hh = (hx711.read(0) - zero)/calib

   --print("hh=", hh)
   
   if hh < 10 then -- weight less than 10 lbs .. leave needle at 0 (off)
      switec.moveto(0, 0, delay)
      goodavg = 0
      return
   end

   -- awake with weight > 10 - do a more precise reading

   local raw_reading_sum = 0

   --noted that back to back calls to hx711.read without a small delay corrupts readings
   --until power is cycled. 100usec seems sufficient. wtf.

   for j=1,numread,1 do   
      tmr.delay(100)
      local rr = hx711.read(0)
      raw_reading_sum = raw_reading_sum + rr
   end
   
   local raw_reading = raw_reading_sum / numread
   
   local reading = raw_reading - zero
   
   local weight = reading / calib
   
   local is = 0

   if weight > 10 then
      goodavg = goodavg + 1
      if goodavg > 2 then -- throw away first readings .. as weight is applied to scale
	 avgweight = avgweight + (weight - avgweight)/10 -- slow moving average - maybe change to boxcar?
      elseif goodavg > 0 then
	 avgweight = weight
	 is = math.floor((30-22.5)*3 + 0.5)
	 switec.moveto(0, is, delay)
	 return
      end
         
      local text = string.format("%4.2f lbs", avgweight)
      print(text)

      hx711.init(4,0) -- this also puts the hx711 back to sleep

      local movdeg = 180 + 150*(avgweight - tgtweight)/10 -- 150 deg is 10 lb (each dir)

      -- device moves over 315 degrees .. use 300 degrees as "active area" for weight readings
      
      if movdeg < 30  then movdeg =  30 end
      if movdeg > 330 then movdeg = 330 end
      
      if goodavg > 2 then
	 is = math.floor((movdeg-22.5)*3 + 0.5)
      else
	 is = 0
      end
      
   end
   switec.moveto(0, is, delay)
end

-- start of main program

hx711.init(4,0)

calib = 11010.8 -- measured against commercial scale
numzero = 5
numread = 5
outlier = 0
tgtweight = 270
goodavg = 0
swireset = true




zero = 0

for i = 1, numzero, 1 do
   local zz = hx711.read(0)
   if i == 1 then print("zz=", zz) end
   zero = zero + zz
   tmr.delay(100) -- hx711.read needs a small delay. no idea why. 100 usec seems sufficient
end

zero = zero / numzero

-- setup motor control: channel 0, pins 5,6,7,8 and 200 deg/sec

switec.setup(0,5,6,7,8,200)

-- position specified in 1/3s of degree so it goes from 0 to 945 (315 degrees full scale * 3)

switec.moveto(0, -1000, delay) -- force against CCW stop befor reset (done in delay())



