local net = require("@lute/net")

print("connecting to echo server...")

local ws: net.WebSocket
ws = net.websocket("wss://echo.websocket.org", {
	onopen = function()
		print("websocket opened")
		ws:send("hello from lute over websockets")
		ws:send("close")
	end,
	onmessage = function(message, binary)
		print("received:", message, "binary:", binary)
		if message == "close" then
			print("closing...")
			ws:close()
		end
	end,
	onclose = function()
		print("websocket closed")
	end,
	onerror = function(err)
		warn("websocket error:", err)
	end,
})

print("connected, waiting for messages...")
