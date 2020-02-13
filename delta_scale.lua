function print_socket(str)
   -- does not block on waiting till last message sent, so given esp8266 runtime it risks
   -- losing messages sent too close in time. not sure it's worth it to buffer it...sck:send can
   -- take a completion callback function for this purpose..
   -- also does not work till an IP addr is obtained (obviously) so if we buffer we can account for
   -- that too... sigh
   srv = net.createConnection(net.TCP, 0)
   srv:on("receive", function(sck, c) print("c:",c) end)
   -- Wait for connection before sending.
   srv:on("connection", function(sck, c)
	     --print("in connection, about to send")
	     --print("sck, c:", sck, c)
	     sck:send(str)
	     sck:close()
   end)
   srv:connect(10138, "10.0.0.48")
end

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
   text= sjson.encode({["survey-path"] = config_tbl.fR3,
	 data = {[config_tbl.fR3Q1] = data1, [config_tbl.fR3Q2]=data2, [config_tbl.fR3Q3]=data3}})
   return http.post(config_tbl.AWSfwd, nil, text, _0_)
end

local function send_four_via_forwarder(iuser, data1, data2, data3, data4)
   local function _0_(code, data)
      return print("four:", code, data, iuser)
   end
   if iuser == 1 then
      text= sjson.encode({["survey-path"] = config_tbl.fR4_U1,
	    data ={[config_tbl.fR4_U1_Q1] = data1, [config_tbl.fR4_U1_Q2]=data2,
	       [config_tbl.fR4_U1_Q3]=data3, [config_tbl.fR4_U1_Q4]=data4}})
   else
      text= sjson.encode({["survey-path"] = config_tbl.fR4_U2,
	    data ={[config_tbl.fR4_U2_Q1] = data1, [config_tbl.fR4_U2_Q2]=data2,
	       [config_tbl.fR4_U2_Q3]=data3, [config_tbl.fR4_U2_Q4]=data4}})
   end
   
   return http.post(config_tbl.AWSfwd, nil, text, _0_)
end

function ipcallback(T)
   wifi_sta=T.IP
   print("IP:", wifi_sta)
   send_mult_via_forwarder(0, vbatt1, vbatt2)   
   print_socket("Delta Scale Awake - IP:"..wifi_sta)
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

function dispSleepNow()
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

function dispSleep()
   switec.moveto(0, 0, dispSleepNow)
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

-- scale calib factors -- zero measured each time, calib over-ridden by value in delta_config.jsn
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
wtboxlen=5
lock = false
lockwt = 0
lastread = 0
tgtweight = 0
wifi_ipa = nil

-- state of sent data to google surveys
sent_to_google=false

-- persistent state of last weights for user(s)
-- separate from rest of configs since it's written on each weighing
targetfile="delta_target.jsn"
target_tbl={}
iuser = 0

--strings for google survey responses, AWS forwarder and gain calibration
configfile="delta_config.jsn"
config_tbl={}

-- main reading loop

function read()
   rr = hx711.read(0)
   
   wt = (rr - zero)/calib

   if math.abs(wt-lastread) > 2 then -- last two readings within about 1%   
      lastread = wt
      --print("|wt-lastread| > 2")
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

   if wt > 10 then -- someone is on the scale
      
      -- select which user this is. handle normal ops and initial setting of table
      if iuser == 0 then
	 if target_tbl[1] == 0 then target_tbl[1] = wt end
	 if target_tbl[2] == 0 and (math.abs(wt - target_tbl[1]) > 10) then
	    target_tbl[2] = wt
	 end
	 if math.abs(wt - target_tbl[1]) <= math.abs(wt - target_tbl[2]) then
	    iuser = 1
	 else
	    iuser = 2
	 end
	 tgtweight = target_tbl[iuser]
	 print_socket(string.format("iuser,tgtweight: %d %f", iuser, tgtweight))
      end
      
      wtboxcar[iwt] = wt
      --print_socket(string.format("iwt, wt %d %f", iwt, wt))
      
      -- compute average and sum of squares of values in wtboxcar{}
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

      -- keep track of readings. wtboxlen is ring buffer, jwt tracks total
      -- and ensures we have a full ring buffer in addition to acceptable stddev
      -- jwt >= wtboxlen+2 effectively tosses the first two readings while stabilizing
      jwt = jwt + 1

      if (jwt >= wtboxlen+4) and (stddev < 0.15)  and (not lock) then
	 lock = true
	 lockwt = (math.floor(avg*10) + 0.5) / 10 -- round to nearest 0.1 lb
	 print_socket(string.format("Lock: %f %d", lockwt, jwt))
      else
	 if iwt >= wtboxlen then
	    iwt = 1
	 else
	    iwt = iwt + 1
	 end
      end
      
      -- make sure we don't go to sleep in the middle of this, wakeup and clear display buffer
      dispSleepTimer:stop()
      disp:setPowerSave(0)
      disp:clearBuffer()

      -- display jwt as progress indicator (sort of ugly on display)
      cdisp(u8g2.font_6x10_tf, string.format("%d", jwt), 115, 45)

      -- do cute "rotating pie slice" with drawDisc to show progress
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
      
      -- display lock weight or running average as weighing proceeds
      cdisp(u8g2.font_inb24_mr, text, 0, 40)

      -- if good reading (boxcar avg within sumsq tolerance) tell user to get off else show last wt
      if lock then
	 text = "GTFO"
      else
	 text = string.format("(%.1f)", tgtweight)
      end

      cdisp(u8g2.font_inb16_mr, text, 0, 55)

      disp:sendBuffer()

      -- move the display needle to the avg or to the lock weight as apprpriate
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
      if lock then -- we have a lock, and wt < 10 so the user is off the scale .. record and tidy up
	 tgtweight = lockwt
	 if not sent_to_google and wifi_sta then -- make sure only done once, and only if wifi online
	    send_four_via_forwarder(iuser, lockwt, zero, calib, vbatt1) -- use (clean) initial adc reading
	    sent_to_google=true
	    cdisp(u8g2.font_6x10_tf, string.format("Sent: IP=%s", wifi_sta), 0, 63)
	    disp:sendBuffer()
	    if file.open(targetfile, "w+") and (iuser ~= 0 ) then -- persist lockwt as new tgtweight
	       target_tbl[iuser] = lockwt
	       --print("iuser, target_tbl[iuser], lockwt:", iuser, target_tbl[iuser], lockwt)
	       tt=sjson.encode(target_tbl)
	       --print("tt=", tt)
	       file.write(tt)
	       file.close()
	    else
	       print("ErrT")
	    end
	 end
	 --switec.moveto(0, 0, swiendread) -- removed .. don't move needle at this moment
      else -- if not lock...
	 switec.moveto(0, 0, swiendread)
      end
      dispSleepTimer:start()
   end
end

--[[

Formal start of execution. Print a wakeup message.

   -- take gpio3 low .. it will go high later to power off the power controller
   -- check battery with no significant load. save for reporting when wifi online
   -- setup wifi and register callback on getting IP addr
   -- open the target weight file and read the last weights for users 
   -- read other configs (wifi, AWS fwder, google survey

--]]

print("Delta Scale")

gpio.mode(3, gpio.OUTPUT)
gpio.write(3,0)

vbatt1 = adc.read(0)

-- check for and open the persistence file that contains the last weights of the users (now 2)
-- if none exists, start with a new file filled with zeros plus a calib const

if file.exists(targetfile) then
   if file.open(targetfile, "r") then
      target_tbl = sjson.decode(file.read())
      print("read and decoded targetfile:", target_tbl[1], target_tbl[2])
      file.close()
   else
      print("Err:T")
   end
else
   print("Info:T") -- no target file exists .. seed values, write later
   target_tbl = {0,0}
end

-- read the config file

if file.exists(configfile) then
   if file.open(configfile, "r") then
      config_tbl = sjson.decode(file.read())
      file.close()
   else
      print("Err:C")
   end
else
   print("NoF:C")
end

calib = config_tbl.calib

-- start up wifi in STA mode, setup a callback for when IP is assigned

print("config_tbl.ssid:", config_tbl.ssid)
print("config_tbl.pwd:", config_tbl.pwd)

print("setmode:", wifi.setmode(wifi.STATION))
print("config:", wifi.sta.config(config_tbl))
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, ipcallback)

-- init the display, scale and then get and remember average of the scale zero

init_i2c_display()

hx711.init(4,0)

local zs = 0
for i=1, 5, 1 do
   tmr.delay(500)
   zs = zs + hx711.read(0)
end
zero = zs/5

-- wake up the display, and clear any remnants in buffer

disp:setPowerSave(0)
disp:clearBuffer()

--display startup messages on OLED

cdisp(u8g2.font_6x10_tf, string.format("Delta Scale V%.1f", 1.0),             0, 20)
cdisp(u8g2.font_6x10_tf, "--> Step On <--",                                   0, 30)
cdisp(u8g2.font_6x10_tf, string.format("(%4.2f, %4.2f)",
				               target_tbl[1], target_tbl[2]), 0, 40)
cdisp(u8g2.font_6x10_tf, string.format("Heap: " .. node.heap()),              0, 50)

disp:sendBuffer()

-- for debugging: meas battery again, with display and scale operating .. log to google from ipcallback

vbatt2 = adc.read(0)

-- set up timers for periodic reading, and for going to sleep if no activity

readtimer=tmr.create()
readtimer:register(500, tmr.ALARM_SEMI, read)

dispSleepTimer=tmr.create()
dispSleepTimer:register(10000, tmr.ALARM_SEMI, dispSleep)

-- setup motor control: channel 0, pins 5,6,7,8 and 200 deg/sec
-- position specified in 1/3s of degree so it goes from 0 to 945 (315 degrees full scale * 3)

switec.setup(0,5,6,7,8,200)

-- force against CCW stop before reset to calibrate "0" (done in swiendrst())
-- if always returned to physical zero, perhaps we could just do -10??

switec.moveto(0, -10, swiendrst) 
