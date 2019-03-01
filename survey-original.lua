local the_survey_url = "/forms/d/e/1FAIpQLSc27KLo5aBIgx45hESfawyI4q3KHZmnmVlG89K0aZoAZTOb-A/formResponse"
local the_entry_key = "entry.481836690"
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
local counter = 0
do
  local t = tmr.create()
  local function _1_(t)
    send_to_survey(counter)
    counter = (1 + counter)
    return nil
  end
  t:register(5000, tmr.ALARM_AUTO, _1_)
  return t:start()
end
