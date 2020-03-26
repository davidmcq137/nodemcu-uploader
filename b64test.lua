local open = false

function execCmd(k,v,data)
   if k =="Opn" then
      file.open("foo.tst", "w")
      open = true
   elseif k == "Cls" then
      file.close()
      open = false
   else
      file.writeline(data)
   end
end

function uartCB(data)
   -- called back here with commands coming in from app
   -- commands of the form "(Command:Val)\n"
   -- pickup one per callback cycle and execute it
   local k,v
   print("data:", data)
   k,v = string.match(data, "(%a+)%s*%p*%s*(%d*)")
   print("k,v:", k, v)
   execCmd(k,v,data)
end



-- Main prog and init seciton starts here

-- First init the UART to talk BLE to the app
print("b64test.lua .. going to 9600 baud")
uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
uart.on("data","\n", uartCB, 0)
--for i=1,100,1 do
   print(i,"b64test.lua .. at 9600 baud")
--end
--file.open("test.tst", "w")





