local client = require("@lute/net/client")

print("connecting to echo server...")

local socket: { client.WebSocket? } = { nil }
socket[1] = client.websocket("wss://echo.websocket.events", {
	onopen = function()
		print("websocket opened")
		local ws = socket[1]
		if ws then
			ws:send("hello from lute over websockets")
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
			local ws = socket[1]
			if ws then
				ws:close()
			end
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
