function print_socket(str)
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

print_socket("Hi there!")



