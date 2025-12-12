local net = require("@lute/net")

print("starting server on ws://127.0.0.1:3000")

local server = net.serve({
	hostname = "127.0.0.1",
	port = 3000,
	handler = function(req: net.ReceivedRequest, server: net.Server): net.ServerResponse?
		if server:upgrade(req) then
			return nil
		end
		return {
			status = 200,
			body = "Hello over HTTP. Try websocket upgrade.",
		}
	end,
	websocket = {
		open = function(ws: net.ServerWebSocket)
			print("ws open")
			ws:send("welcome")
		end,
		message = function(ws, message, binary)
			print("ws message:", message, "binary:", binary)
			ws:send(message, binary)
			if message == "close" then
				ws:close()
			end
		end,
		close = function(_ws, code, message)
			print("ws close:", code, message)
		end,
		drain = function(_ws)
			print("ws drain")
		end,
	},
})

print(`listening on {server.hostname}:{server.port}`)
