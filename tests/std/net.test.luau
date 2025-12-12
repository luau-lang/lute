local net = require("@std/net")
local test = require("@std/test")
local task = require("@lute/task")

test.suite("NetTestSuite", function(suite)
	suite:case("serve_locally_and_request", function(assert)
		local server = net.serve({
			handler = function(req: net.receivedrequest): net.serverresponse
				return {
					status = 200,
					body = "Hello, World!",
				}
			end,
		})

		local response = net.request(`{server.hostname}:{server.port}`, {
			method = "GET",
		})
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq("Hello, World!", response.body)

		server.close()
	end)

	suite:case("serve_websocket_and_connect", function(assert)
		local receivedEcho = false
		local clientClosed = false
		local serverCloseCode: number? = nil
		local serverCloseMessage: string? = nil

		local server = net.serve({
			handler = function(req: net.receivedrequest, server: net.server): net.serverresponse?
				if server:upgrade(req) then
					print("upgraded")
					return nil
				end
				return {
					status = 200,
					body = "no upgrade",
				}
			end,
			websocket = {
				message = function(ws, message)
					print("server received message:", message)
					ws:send(message)
					if message == "bye" then
						ws:close(4001, "done")
					end
				end,
				close = function(_ws, code, message)
					print("server closed socket with code:", code, "and message:", message)
					serverCloseCode = code
					serverCloseMessage = message
				end,
			},
		})

		local ws: net.websocket
		ws = net.websocket(`ws://{server.hostname}:{server.port}`, {
			onopen = function()
				print("client opened")
				ws:send("hello")
			end,
			onmessage = function(message)
				print("client received message:", message)
				if message == "hello" then
					receivedEcho = true
					ws:send("bye")
				end
			end,
			onclose = function()
				print("client closed")
				clientClosed = true
			end,
			onerror = function(err: string): ()
				error(err)
			end,
		})

		local start = os.clock()
		while (not receivedEcho or not clientClosed or serverCloseCode == nil) and os.clock() - start < 5 do
			task.defer()
		end

		assert.eq(true, receivedEcho)
		assert.eq(true, clientClosed)
		assert.eq(4001, serverCloseCode)
		assert.eq("done", serverCloseMessage)

		server.close()
	end)
end)

test.run()
