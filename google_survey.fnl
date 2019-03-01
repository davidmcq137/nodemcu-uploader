;; other survey "/forms/d/e/1FAIpQLSelOx6I1Mv7x6Xg7f7vti9Qx7y5hQHms9LdCpZhYFutPZfZOg/formResponse"
;; entry "entry.1803841049"
;;(local the-survey-url "/forms/d/e/1FAIpQLSc27KLo5aBIgx45hESfawyI4q3KHZmnmVlG89K0aZoAZTOb-A/formResponse")
;;(local the-entry-key "entry.481836690")

(local the-survey-url "/forms/d/e/1FAIpQLSelOx6I1Mv7x6Xg7f7vti9Qx7y5hQHms9LdCpZhYFutPZfZOg/formResponse")
(local the-entry-key "entry.1803841049")

(fn send-via-forwarder
  [datapoint]
  (http.post "http://54.245.181.150:4321"
             nil
             (sjson.encode {:survey-path the-survey-url
                            :data {the-entry-key datapoint}})
             (fn [code data]
               (print "got response " code))))


