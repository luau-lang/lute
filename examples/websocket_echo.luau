local client = require("@lute/net/client")

print("connecting to echo server...")

local _ws: client.WebSocket?
_ws = client.websocket("_wss://echo.websocket.org", {
	onopen = function()
		print("websocket opened")
		if _ws then
			_ws:send("hello from lute over websockets")
			_ws:send(buffer.create(4))
			_ws:send("close")
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
			if _ws then
				_ws:close()
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
