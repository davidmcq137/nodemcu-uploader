if file.exists("target.dat") then
   print("target.dat exists, reading")
   if file.open("target.dat", "r") then
      rl = file.readline()
      print("read:", rl)
      tgt = tonumber(rl)
      print("tgtweight:", tgt)
   else
      print("could not open target.dat for reading")
   end
else
   tgt = 270.0
end

tgt = tgt + 1.5

if file.open("target.dat", "w+") then
   print("writing:", tgt)
   file.writeline(string.format("%f", tgt))
   file.close()
else
   print("could not open target.dat")
end
