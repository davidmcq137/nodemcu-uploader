local the_survey_url = "/forms/d/e/1FAIpQLSelOx6I1Mv7x6Xg7f7vti9Qx7y5hQHms9LdCpZhYFutPZfZOg/formResponse"
local the_entry_key = "entry.1803841049"

local function send_via_forwarder(datapoint)
   local function _0_(code, data)
      return print("got response ", code)
   end
   return http.post("http://54.245.181.150:4321", nil, sjson.encode({["survey-path"] = the_survey_url, data = {[the_entry_key] = datapoint}}), _0_)
end


print("starting")
foo=send_via_forwarder(199.9)
print("return:", foo)
