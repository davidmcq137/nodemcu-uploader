function six(a,b,c)
   print("in six")
   print("a,b,c:", a,b,c)
   print("cal:", cal)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   print("done, closing")
   switec.close(0)
end

function five()
   print("in five")
   print("cal:", cal)
   print("done, resetting")
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   switec.moveto(0, 0, function() return six(1,2,3) end)
end

function four()
   print("in four")
   print("cal:", cal)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   tmr.create():alarm(5000, tmr.ALARM_SINGLE, five)
end


function three()
   print("in three")
   print("cal:", cal)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   switec.moveto(0,800, four)
end

function two()
   print("in two")
   print("cal:", cal)
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   switec.moveto(0, 500, three)
end

function one()
   print("in one")
   print("resetting")
   switec.reset(0)
   cal = false
   local p,m = switec.getpos(0)
   print("getpos", p,m)
   switec.moveto(0, 250, two)
end

print("starting - doing setup")
a = switec.setup(0,5,6,7,8,400)
print("setup returns:", a)

print("first moveto - drive to CCW stop")
cal = true
switec.moveto(0, -1000, one)
print("done with moveto -1000")



