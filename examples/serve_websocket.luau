local server = require("@lute/net/server")

print("starting server on ws://127.0.0.1:3000")

local instance = server.serve({
	hostname = "127.0.0.1",
	port = 3000,
	handler = function(req: server.ReceivedRequest, instance: server.Server): server.ServerResponse?
		if instance:upgrade(req) then
			return nil
		end

		return {
			status = 200,
			body = "Hello over HTTP. Try websocket upgrade.",
		}
	end,
	websocket = {
		open = function(ws: server.ServerWebSocket)
			print("ws open")
			ws:send("welcome")
		end,
		message = function(ws, message)
			if type(message) == "buffer" then
				print("ws binary message len:", buffer.len(message))
			else
				print("ws message:", message)
				if message == "close" then
					ws:close()
				end
			end
			ws:send(message)
		end,
		close = function(_ws, code, message)
			print("ws close:", code, message)
		end,
		drain = function(_ws)
			print("ws drain")
		end,
	},
})

print(`listening on {instance.hostname}:{instance.port}`)
