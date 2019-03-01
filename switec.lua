function stopped()
   print("stopped callback")
end

print("starting - doing setup")
a = switec.setup(0,5,6,7,8,200)
print("setup returns:", a)

print("neg move")
cal = true
switec.moveto(0, -1000, function()
		 print("CALLBACK RESET")
		 switec.reset(0)
		 cal = false
end)

tmr.delay(10000000)

while true do
   tmr.delay(100000)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   if m == 0 then break end
end

print("resetting")

switec.reset(0)

print("while loop")

while true do
   tmr.delay(100000)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   if m == 0 then break end
end

print("moveto 250")
switec.moveto(0, 250,
	      function()
		 print("moveto 0 stopped")
end)

while true do
   tmr.delay(100000)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   if m == 0 then break end
end


print("moveto 500")
switec.moveto(0, 500, stopped)
while true do
   tmr.delay(100000)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   if m == 0 then break end
end


print("moveto 1000")
switec.moveto(0, 1000, stopped)
while true do
   tmr.delay(100000)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   if m == 0 then break end
   tmr.delay(100000)
end

print("moveto 0")
switec.moveto(0, 0, stopped)
while true do
   tmr.delay(100000)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   if m == 0 then break end
end


print("closing")

switec.close(0)

