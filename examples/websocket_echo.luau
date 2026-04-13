local client = require("@lute/net/client")

print("connecting to echo server...")

local ws: client.WebSocket?
ws = client.websocket("wss://echo.websocket.org", {
	onopen = function()
		print("websocket opened")
		if ws then
			ws:send("hello from lute over websockets")
			ws:send(buffer.create(4))
			ws:send("close")
		end
	end,
	onmessage = function(message)
		if type(message) == "buffer" then
			print("received binary message len:", buffer.len(message))
			return
		end

		print("received:", message)
		if message == "close" then
			print("closing...")
			if ws then
				ws:close()
			end
		end
	end,
	onclose = function()
		print("websocket closed")
	end,
	onerror = function(err)
		print("websocket error:", err)
	end,
})

print("connected, waiting for messages...")
