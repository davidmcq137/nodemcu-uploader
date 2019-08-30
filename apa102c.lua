a1=15
b1=128
g1=0
r1=0
a2=15
b2=0
g2=128
r2=0
a3=15
b3=0
g3=0
r3=128
a={31,31,31}
b={255, 0, 0}
g={0,255,0}
r={0,0,255}

R=1
G=100
B=150

i=1
l=1

local myt = tmr.create()

function tmrcb2()

   leds_arbg = string.char(31,R,B,G):rep(5)
   apa102.write(2,3,leds_arbg)
   R=node.random(0,255)
   G=node.random(0,255)
   B=node.random(0,255)

   
   myt:start()

end

function tmrcb()
   --leds_arbg = string.char(a[i],r[i],b[i],g[i])

   for kk=2,5,1 do
      j=i
      --j= 1+ ((i+kk-1) % 3)
--      print("kk,i,j:", kk, i, j)
      print(a[j], r[j], b[j], g[j])
      --leds_arbg = leds_arbg .. string.char(a[j], r[j], b[j], g[j])
      leds_arbg = leds_arbg .. string.char(a[j], r[j], r[j], r[j])
   end
   apa102.write(2,3,leds_arbg)
   l=l+1
   if l > 31 then l=1 end
   i=i+1
   if i>3 then i=1 end
   do jj=1,3,1
      r[jj] = r[jj] + 5
      if r[jj] > 255 then r[jj]=1 end
      --g[jj] = g[jj] + 5
      --if g[jj] > 255 then g[jj]=1 end
      --b[jj] = b[jj] + 5
      --if b[jj] > 255 then b[jj]=1 end      
   end
   
   myt:start()
end

myt:register(10, tmr.ALARM_SEMI, tmrcb2)
myt:start()


