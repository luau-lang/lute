local test = require("@std/test")

local client = require("@lute/net/client")
local server = require("@lute/net/server")
local task = require("@lute/task")

test.suite("LuteNetSuite", function(suite)
	suite:case("serveWebsocketAndConnect", function(assert)
		local receivedEcho = false
		local clientClosed = false
		local serverCloseCode: number? = nil
		local serverCloseMessage: string? = nil
		local firstServerSendResult: number? = nil

		local instance = server.serve({
			handler = function(req: server.ReceivedRequest, current: server.Server): server.ServerResponse?
				if current:upgrade(req) then
					return nil
				end

				return {
					status = 200,
					body = "no upgrade",
				}
			end,
			websocket = {
				message = function(ws, message)
					local sendResult = ws:send(message)
					if firstServerSendResult == nil then
						firstServerSendResult = sendResult
					end
					if message == "bye" then
						ws:close(4001, "done")
					end
				end,
				close = function(_ws, code, message)
					serverCloseCode = code
					serverCloseMessage = message
				end,
			},
		})

		local ws: client.WebSocket?
		ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if ws then
					ws:send("hello")
				end
			end,
			onmessage = function(message)
				if type(message) == "string" and message == "hello" then
					receivedEcho = true
					if ws then
						ws:send("bye")
					end
				end
			end,
			onclose = function()
				clientClosed = true
			end,
			onerror = function(err: string)
				error(err)
			end,
		})

		local start = os.clock()
		while (not receivedEcho or not clientClosed or serverCloseCode == nil) and os.clock() - start < 5 do
			task.deferSelf()
		end

		assert.eq(true, receivedEcho)
		assert.eq(true, clientClosed)
		if firstServerSendResult == nil then
			error("server send result was not captured")
		end
		if serverCloseCode == nil or serverCloseMessage == nil then
			error("websocket close callback did not run")
		end
		assert.eq(true, firstServerSendResult > 0)
		assert.eq(4001, serverCloseCode)
		assert.eq("done", serverCloseMessage)

		instance.close()
	end)

	suite:case("serveBinaryWebsocketAndConnect", function(assert)
		local serverSawBinary = false
		local clientSawBinary = false
		local firstServerSendResult: number? = nil
		local payload = buffer.create(4)
		buffer.writeu8(payload, 0, 1)
		buffer.writeu8(payload, 1, 2)
		buffer.writeu8(payload, 2, 3)
		buffer.writeu8(payload, 3, 4)

		local instance = server.serve({
			port = 0,
			handler = function(req: server.ReceivedRequest, current: server.Server): server.ServerResponse?
				if current:upgrade(req) then
					return nil
				end

				return {
					status = 200,
					body = "no upgrade",
				}
			end,
			websocket = {
				message = function(ws, message)
					assert.eq("buffer", type(message))
					serverSawBinary = true

					local sendResult = ws:send(message)
					if firstServerSendResult == nil then
						firstServerSendResult = sendResult
					end
				end,
			},
		})

		local closed = false
		local ws: client.WebSocket?
		ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if ws then
					ws:send(payload)
				end
			end,
			onmessage = function(message)
				if type(message) ~= "buffer" then
					error("expected binary websocket message")
				end
				clientSawBinary = true
				local messageBuffer: buffer = message
				assert.eq(payload, messageBuffer)

				if ws then
					ws:close()
				end
			end,
			onclose = function()
				closed = true
			end,
			onerror = function(err: string)
				error(err)
			end,
		})

		local start = os.clock()
		while (not serverSawBinary or not clientSawBinary or not closed) and os.clock() - start < 5 do
			task.deferSelf()
		end

		assert.eq(true, serverSawBinary)
		assert.eq(true, clientSawBinary)
		assert.eq(true, closed)
		if firstServerSendResult == nil then
			error("binary server send result was not captured")
		end
		assert.eq(true, firstServerSendResult > 0)

		instance.close()
	end)

	suite:case("clientWebsocketCallbacksSurviveGc", function(assert)
		local opened = false

		local instance = server.serve({
			handler = function(req: server.ReceivedRequest, current: server.Server): server.ServerResponse?
				if current:upgrade(req) then
					return nil
				end

				return {
					status = 200,
					body = "no upgrade",
				}
			end,
			websocket = {},
		})

		local _ws: client.WebSocket?
		_ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				opened = true
			end,
		})

		local start = os.clock()
		while os.clock() - start < 0.2 do
		end

		_ws = nil

		do
			local junk = {}
			for i = 1, 20000 do
				junk[i] = string.rep("x", 1024)
			end
		end

		start = os.clock()
		while not opened and os.clock() - start < 2 do
			task.deferSelf()
		end

		assert.eq(true, opened)
		instance.close()
	end)

	suite:case("clientInitiatedCloseRunsOnclose", function(assert)
		local closed = false
		local closeCode: number? = nil
		local closeReason: string? = nil

		local instance = server.serve({
			handler = function(req: server.ReceivedRequest, current: server.Server): server.ServerResponse?
				if current:upgrade(req) then
					return nil
				end

				return {
					status = 200,
					body = "no upgrade",
				}
			end,
			websocket = {},
		})

		local ws: client.WebSocket?
		ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if ws then
					ws:close()
				end
			end,
			onclose = function(code, reason)
				closed = true
				closeCode = code
				closeReason = reason
			end,
			onerror = function(err: string)
				error(err)
			end,
		})

		local start = os.clock()
		while not closed and os.clock() - start < 2 do
			task.deferSelf()
		end

		assert.eq(true, closed)
		if closeCode == nil or closeReason == nil then
			error("client close callback did not capture close details")
		end
		assert.eq(1000, closeCode)
		assert.eq("", closeReason)

		instance.close()
	end)
end)
