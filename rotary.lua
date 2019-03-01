lastTime=0
function rotaryCB(type, pos, time)
   deltaT=math.abs(math.abs(time)-math.abs(lastTime))/1000000
   mins=time/(60*1000000)
   print(string.format("type:%2d pos:%4d time:%12d deltaT:%3.3f mins:%3.2f", type, pos, time, deltaT, mins))
   lastTime = time
end

rotary.setup(0 ,1, 2, 4)

rotary.on(0, rotary.ALL, rotaryCB)


print("foo")

gpio.mode(5, gpio.INT)

kk=0

function gpioCB(lev, pul, cnt)
   print("lev,pul,cnt:", lev, pul, cnt)
   kk=kk+cnt
   print("kk:", kk)
   gpio.trig(5, "up")
end

gpio.trig(5, "up", gpioCB)

   

