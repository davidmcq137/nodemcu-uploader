local cal_intercept = -17800
local cal_coeff = 11010.799999999999
local the_survey_url = "/forms/d/e/1FAIpQLSc27KLo5aBIgx45hESfawyI4q3KHZmnmVlG89K0aZoAZTOb-A/formResponse"
local the_entry_key = "entry.481836690"
local lock_threshold = 0.20000000000000001
local function display_create()
  i2c.setup(0, 2, 1, i2c.SLOW)
  return u8g2.ssd1306_i2c_128x64_noname(0, 60)
end
local function u8g2_setup(display)
  display:setFontRefHeightExtendedText()
  display:setDrawColor(1)
  display:setFontPosBottom()
  return display:setFontDirection(0)
end
local function send_via_forwarder(datapoint)
  local function _0_(code, data)
    return print("got response ", code)
  end
  return http.post("http://54.245.181.150:4321", nil, sjson.encode({["survey-path"] = the_survey_url, data = {[the_entry_key] = datapoint}}), _0_)
end
local function ring_buffer(size)
  local points = {}
  local index = 1
  local function _0_(this, v)
    points[index] = v
    index = (index + 1)
    if (size < index) then
      index = 1
      return nil
    end
  end
  local function _1_(this)
    local i = 0
    local function _2_()
      i = (i + 1)
      return points[i]
    end
    return _2_
  end
  return {push = _0_, values = _1_}
end
local function average(iter)
  local acc = 0
  local count = 0
  for item in iter do
    acc = (acc + item)
    count = (1 + count)
  end
  return (acc / count)
end
local function stddev(avg, iter)
  local acc = 0
  local count = 0
  for item in iter do
    local d = (item - avg)
    acc = (acc + (d * d))
    count = (1 + count)
  end
  return math.sqrt((acc / count))
end
local function read_scale()
  tmr.delay(500)
  return ((hx711.read() + cal_intercept) / cal_coeff)
end
display = display_create()
u8g2_setup(display)
hx711.init(4, 0)
__fnl_global__pending_2dsend = nil
node.egc.setmode(node.egc.ON_MEM_LIMIT, 16384)
do
  local t = tmr.create()
  local sender_timer = tmr.create()
  local buf = ring_buffer(3)
  local function _0_(t)
    print("pending-send = ", __fnl_global__pending_2dsend)
    local function _1_()
      if __fnl_global__pending_2dsend then
        send_via_forwarder(__fnl_global__pending_2dsend)
        __fnl_global__pending_2dsend = nil
        return nil
      end
    end
    _1_()
    return sender_timer:start()
  end
  sender_timer:register(5000, tmr.ALARM_SEMI, _0_)
  sender_timer:start()
  local function _1_(t)
    do
      local reading = read_scale()
      local function _2_()
        if (10 < reading) then
          buf:push(reading)
          do
            local avg = average(buf:values())
            local std = stddev(avg, buf:values())
            print("m,s = ", avg, ", ", std)
            if (std < lock_threshold) then
              __fnl_global__pending_2dsend = avg
              return nil
            end
          end
        end
      end
      _2_()
    end
    return t:start()
  end
  t:register(500, tmr.ALARM_SEMI, _1_)
  return t:start()
end
