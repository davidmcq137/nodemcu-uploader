;; srv = tls.createConnection()
;; srv:on("receive", function(sck, c) print(c) end)
;; srv:on("connection", function(sck, c)
;;   -- Wait for connection before sending.
;;   sck:send("GET / HTTP/1.1\r\nHost: google.com\r\nConnection: keep-alive\r\nAccept: */*\r\n\r\n")
;; end)
;; srv:connect(443,"google.com")


(local the-survey-url "/forms/d/e/1FAIpQLSc27KLo5aBIgx45hESfawyI4q3KHZmnmVlG89K0aZoAZTOb-A/formResponse")
(local the-entry-key "entry.481836690")

(fn make-http-request
    [method url headers body]
    (var request (.. method " " url " HTTP/1.1\r\n"))
    (each [hdr val (pairs headers)]
	  (set request (.. request hdr ": " val "\r\n")))
    (.. request "Content-Length: " (# body) "\r\n\r\n" body))

(fn send-survey-datapoint-request
    [survey-url entry-key data]
    (make-http-request "POST"
		       survey-url
		       {"Host" "docs.google.com"
		       "Content-Type" "application/x-www-form-urlencoded"}
		       (.. entry-key "=" data)))

(fn send-to-survey
    [data]
    (print "sending " data)
    (let [srv (tls.createConnection)]
	 (: srv :on "receive"

	    (fn [socket]
		(print "on receive")
		(: socket :close)))
	 (: srv :on "connection"
	    (fn [socket c]
		(print "on connection")
		(: socket :send	       
		   (doto (send-survey-datapoint-request the-survey-url the-entry-key data) (print)))))
	 (print "connecting")
	 (: srv :connect 443 "docs.google.com")
         (print "connected?")))


(var counter 0)
(let [t (tmr.create)
     tfn (fn [t]
	    (send-to-survey counter)
	    (set counter (+ 1 counter)))]
  (tfn)
  (: t :register 5000 tmr.ALARM_AUTO tfn)
  (: t :start))

