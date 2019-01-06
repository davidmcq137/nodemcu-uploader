function cdisp(font, text, x, y)
   local ww, xd
   disp:setFont(font)
   ww=disp:getStrWidth(text)
   if x == 0 then xd = dw/2 - ww/2 else xd = x end
   disp:drawStr(xd, y, text)
end

local function send_mult_via_forwarder(data1, data2, data3)
   local function _0_(code, data)
      return print("mult:", code, data)
   end
   text= sjson.encode({["survey-path"] = goog_tbl.fR3,
	 data = {[goog_tbl.fR3Q1] = data1, [goog_tbl.fR3Q2]=data2, [goog_tbl.fR3Q3]=data3}})
   return http.post(goog_tbl.AWSfwd, nil, text, _0_)
end

local function send_four_via_forwarder(data1, data2, data3, data4)
   local function _0_(code, data)
      return print("four:", code, data)
   end
   text= sjson.encode({["survey-path"] = goog_tbl.fR4,
	 data ={[goog_tbl.fR4Q1] = data1, [goog_tbl.fR4Q2]=data2,
	    [goog_tbl.fR4Q3]=data3, [goog_tbl.fR4Q4]=data4}})
   return http.post(goog_tbl.AWSfwd, nil, text, _0_)
end

function ipcallback(T)
   --print("\n\tCallback: STA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
   -- T.netmask.."\n\tGateway IP: "..T.gateway)
   wifi_sta=T.IP
   print("IP:", wifi_sta)
   send_mult_via_forwarder(0, vbatt1, vbatt2)   
end

function swiendsleep()
   dispSleepTimer:start()   
end

function swiendread()
   readtimer:start()
end

function swiendrst() -- only call on startup
   switec.reset(0)
   swiendread()
end

function dispSleep()
   switec.moveto(0, 0, swiendread)
   disp:clearBuffer()
   disp:sendBuffer()
   disp:setPowerSave(1)
   lock = false
   sent_to_google=false
   lockwt = 0
   iwt = 1
   jwt = 1
   wtboxcar={}
   iuser = 0
   lastread = 0
   gpio.mode(3, gpio.OUTPUT)
   gpio.write(3,1) -- signal power controller to turn power off
end

function init_i2c_display()
    local sda = 2    -- GPIO4
    local scl = 1    -- GPIO5
    local sla = 0x3c -- i2c addr
    ii = i2c.setup(0, sda, scl, i2c.SLOW)
    disp = u8g2.ssd1306_i2c_128x64_noname(0, sla)
    disp:setFontRefHeightExtendedText()
    disp:setDrawColor(1)
    disp:setFontPosBottom()
    disp:setFontDirection(0)
end

-- scale calib factors
calib = 10957.0
zero = 0

-- screen size in pixels
dh, dw = 64, 128

-- sequence for rotating pie slices while weighing
seq = {u8g2.DRAW_UPPER_RIGHT, u8g2.DRAW_LOWER_RIGHT, u8g2.DRAW_LOWER_LEFT,u8g2.DRAW_UPPER_LEFT}

-- various variables for averaging weight and managing state
iseq = 1
wtboxcar={}
iwt = 1
jwt = 1
wtboxlen=7
lock = false
lockwt = 0
lastread = 0
tgtweight = 0
wifi_ipa = nil

-- state of sent data to google surveys
sent_to_google=false

-- persistent state of last weights for user(s)
persfile="delta_target.jsn"
tgt_table={}
iuser = 0

-- wifi login info (ssid and pw)
wififile="delta_wifi.jsn"
config_tbl={}

--strings for google survey responses and AWS forwarder
googfile="delta_goog.jsn"
goog_tbl={}

-- main reading loop

function read()
   rr = hx711.read(0)
   
   wt = (rr - zero)/calib

   if math.abs(wt-lastread) > 1 then   
      lastread = wt
      --print("|wt-lastread| > 1")
      if not lock then
	 dispSleepTimer:stop()
	 disp:setPowerSave(0)
	 disp:clearBuffer()
	 cdisp(u8g2.font_inb24_mr, "----", 0, 50)
	 disp:sendBuffer()
      end
      switec.moveto(0, 30*3, swiendread)
      --swiendread()
      return
   end

   lastread = wt

   if wt > 10 then

      if iuser == 0 then
	 if math.abs(wt - tgt_table[1]) <= math.abs(wt - tgt_table[2]) then
	    iuser = 1
	 else
	    iuser = 2
	 end
	 tgtweight = tgt_table[iuser]
	 print("iuser,tgtweight:", iuser, tgtweight)
      end
      
      wtboxcar[iwt] = wt

      local sum = 0
      jj = iwt
      for i=1, jj, 1 do
	 sum = sum + wtboxcar[i]
      end
      local avg = sum / jj
      
      local sumsq = 0
      for i=1, jj, 1 do
	 sumsq = sumsq + (avg - wtboxcar[i])^2
      end
      stddev = math.sqrt(sumsq/jj)
      
      jwt = jwt + 1

      if (jwt >= wtboxlen) and (stddev < 0.15)  and (not lock) then
	 lock = true
	 lockwt = (math.floor(wt*10) + 0.5) / 10
      end

      if iwt >= wtboxlen then
	 iwt = 1
      else
	 iwt = iwt + 1
      end
      
      dispSleepTimer:stop()
      disp:setPowerSave(0)
      disp:clearBuffer()

      cdisp(u8g2.font_6x10_tf, string.format("%d", jwt), 115, 45)
      
      local text
      if lock then
	 text = string.format("%3.1f", lockwt)
	 disp:drawDisc(120, 10, 2)
      else
	 text = string.format("%3.1f", avg)
	 disp:drawDisc(120, 10, 2, seq[iseq])
	 if iseq == #seq then
	    iseq = 1
	 else
	    iseq = iseq + 1
	 end
      end
      
      cdisp(u8g2.font_inb24_mr, text, 0, 40)

      if lock then
	 text = "GTFO"
      else
	 text = string.format("(%.1f)", tgtweight)
      end

      cdisp(u8g2.font_inb16_mr, text, 0, 55)

      disp:sendBuffer()
      
      if lock then swiwt = lockwt else swiwt = avg end
      local movdeg = 180 + 120 * (swiwt - tgtweight) / 3
      if movdeg < 30 then movdeg = 30 end
      if movdeg > 330 then movdeg = 330 end
      is = math.floor(movdeg * 3 + 0.5)
      if jwt > 2 then
	 switec.moveto(0, is, swiendread)
      else
	 switec.moveto(0, 30*3, swiendread)
      end
      
   else -- wt <= 10
      is = 0
      if lock then
	 tgtweight = lockwt
	 if not sent_to_google and wifi_sta then -- make sure only done once
	    vbatt = adc.read(0)
	    send_four_via_forwarder(lockwt, zero, calib, vbatt)
	    sent_to_google=true
	    cdisp(u8g2.font_6x10_tf, string.format("Sent: IP=%s", wifi_sta), 0, 63)
	    disp:sendBuffer()
	    if file.open(persfile, "w+") and (iuser ~= 0 ) then -- persist lockwt as new tgtweight
	       tgt_table[iuser] = lockwt
	       file.write(sjson.encode(tgt_table))
	       file.close()
	    else
	       print("ErrT")
	    end
	 end
	 --switec.moveto(0, 0, swiendread)
      else -- if not lock...
	 switec.moveto(0, 0, swiendread)
      end
      dispSleepTimer:start()
   end
end

-- wakeup here. take gpio3 low .. it will go high later to power off the power controller
-- then setup wifi and register callback on getting IP addr
-- then check battery with no significant load. save for reporting when wifi online
-- then open the persist file and read the last weight and off we go..

print("Delta Scale")

gpio.mode(3, gpio.OUTPUT)
gpio.write(3,0)

vbatt1 = adc.read(0)

-- read the wifi config file to get ssid and pw and other wifi state, start the station

if file.exists(wififile) then
   if file.open(wififile, "r") then
      config_tbl = sjson.decode(file.read())
      file.close()
   else
      print("ErrWiFi")
   end
else
   print("NoWifi")
end

wifi.setmode(wifi.STATION)
wifi.sta.config(config_tbl)
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, ipcallback)

-- check for and open the persistence file that contains the last weights of the users (now 2)
-- if none exists, start with a new file filled with zeros

if file.exists(persfile) then
   if file.open(persfile, "r") then
      tgt_table = sjson.decode(file.read())
      file.close()
   else
      print("ErrO")
   end
else
   print("Info:T")
   tgt_table={0, 0}
end

-- read the google survey config file

if file.exists(googfile) then
   if file.open(googfile, "r") then
      goog_tbl = sjson.decode(file.read())
      file.close()
   else
      print("ErrGoog")
   end
else
   print("NoGoog")
end

-- init the display, scale and steppers, then get and remember average of the scale zero

init_i2c_display()

hx711.init(4,0)

local zs = 0
for i=1, 5, 1 do
   tmr.delay(500)
   zs = zs + hx711.read(0)
end
zero = zs/5

-- wake up the display, and clear remnants of buffer

disp:setPowerSave(0)
disp:clearBuffer()

cdisp(u8g2.font_6x10_tf, string.format("Delta Scale V%.1f", 1.0),             0, 20)
cdisp(u8g2.font_6x10_tf, "--> Step On <--",                                   0, 30)
cdisp(u8g2.font_6x10_tf, string.format("(%5.2f, %5.2f)",
				                 tgt_table[1], tgt_table[2]), 0, 40)
cdisp(u8g2.font_6x10_tf, string.format("Heap: " .. node.heap()),              0, 50)

disp:sendBuffer()

-- for debugging: meas battery again, with display and scale operating .. log to google from ipcallback

vbatt2 = adc.read(0)

-- set up timers for periodic reading, and for going to sleep if no activity

readtimer=tmr.create()
readtimer:register(1000, tmr.ALARM_SEMI, read)

dispSleepTimer=tmr.create()
dispSleepTimer:register(10000, tmr.ALARM_SEMI, dispSleep)

-- setup motor control: channel 0, pins 5,6,7,8 and 200 deg/sec
-- position specified in 1/3s of degree so it goes from 0 to 945 (315 degrees full scale * 3)

switec.setup(0,5,6,7,8,200)

-- force against CCW stop before reset (done in swiendrst())

switec.moveto(0, -1000, swiendrst) 
