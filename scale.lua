local cal_intercept = -17800
local cal_coeff = 11010.799999999999
local the_survey_url = "/forms/d/e/1FAIpQLSc27KLo5aBIgx45hESfawyI4q3KHZmnmVlG89K0aZoAZTOb-A/formResponse"
local the_entry_key = "entry.481836690"
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
local function make_http_request(method, url, headers, body)
  local request = (method .. " " .. url .. " HTTP/1.1\13\n")
  for hdr, val in pairs(headers) do
    request = (request .. hdr .. ": " .. val .. "\13\n")
  end
  return (request .. "Content-Length: " .. #body .. "\13\n\13\n" .. body)
end
local function send_survey_datapoint_request(survey_url, entry_key, data)
  return make_http_request("POST", survey_url, {Host = "docs.google.com", ["Content-Type"] = "application/x-www-form-urlencoded"}, (entry_key .. "=" .. data))
end
local function send_to_survey(data)
  print("sending ", data)
  do
    local srv = tls.createConnection()
    local function _0_(socket)
      return socket:close()
    end
    srv:on("receive", _0_)
    local function _1_(socket, c)
      local function _2_()
        local _0_0 = send_survey_datapoint_request(the_survey_url, the_entry_key, data)
        print(_0_0)
        return _0_0
      end
      return socket:send(_2_())
    end
    srv:on("connection", _1_)
    return srv:connect(443, "docs.google.com")
  end
end
local function moving_averager(window_size)
  local points = {}
  local index = 1
  local function _1_(this, v)
    print("add-reading ", v)
    points[index] = v
    index = (index + 1)
    if (index == window_size) then
      index = 0
      return nil
    end
  end
  local function _2_(this)
    local acc = 0
    for i, v in ipairs(points) do
      acc = (acc + v)
    end
    print("acc", acc, " n.points", #points)
    return (acc / #points)
  end
  return {["add-reading"] = _1_, ["get-average"] = _2_}
end
local function read_scale()
  tmr.delay(500)
  return ((hx711.read() + cal_intercept) / cal_coeff)
end
display = display_create()
u8g2_setup(display)
hx711.init(4, 0)
do
  local t = tmr.create()
  local function _1_(t)
    do
      local initial_reading = read_scale()
      local function _2_()
        if (10 < initial_reading) then
          local ra = initial_reading
          local rb = read_scale()
          while (0.5 > math.abs((rb - ra))) do
            print("diff= ", (rb - ra))
            ra = rb
            rb = read_scale()
          end
          return send_to_survey(((ra + rb) / 2))
        end
      end
      _2_()
    end
    return t:start()
  end
  t:register(500, tmr.ALARM_SEMI, _1_)
  return t:start()
end
