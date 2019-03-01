function drawLCD(rT, fR, pP, pC, pW)
   local io = 2

   cdisp(u8g2.font_profont17_mr, string.format("Vol %.1f oz",   pC/pulsePerOz), 1,  0+io)
   local irt = math.min(runningTime)
   if rT <= 59 then
      cdisp(u8g2.font_profont17_mr, string.format("Tim %2d sec",  math.floor(irt)), 1, 15+io)
   else
      local min = math.floor(irt/60)
      local sec = math.floor(irt-60*min)
      cdisp(u8g2.font_profont17_mr, string.format("Tim %2d:%02d min",  min, sec), 1, 15+io)
   end

   tickTock = tmr.time()
   if tickTock%6 < 3 and pW > minPWM then
      cdisp(u8g2.font_profont17_mr, string.format("Flw %.1f oz/m", fR), 1, 30+io)
   else
      cdisp(u8g2.font_profont17_mr, string.format("P   %.1f psi", pP),  1, 30+io)
   end
   
   cdisp(u8g2.font_6x10_tf, "Empty", 20, 53)
   cdisp(u8g2.font_6x10_tf, "Fill",  85, 53)

   disp:drawFrame(1, 52, 127, 12)

   local pS = 100 * pW/1023
   local k = math.floor(0.5 + (pS/100)*63)
   local j = math.floor(63*minPWM/1023)

   disp:drawFrame(64-j, 52, 2*j, 12)

   if pumpFwd then
      disp:drawBox(64, 52, k, 12)
   else
      disp:drawBox(64-k, 52, k, 12)      
   end
   disp:drawVLine(64,52,12)
   disp:sendBuffer()
end
