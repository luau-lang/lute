local test = require("@std/test")

local client = require("@lute/net/client")
local server = require("@lute/net/server")
local task = require("@lute/task")

test.suite("LuteNetSuite", function(suite)
	suite:case("serveWebsocketSynchronousMessageEchoAndClose", function(assert)
		local receivedEcho = false
		local clientClosed = false
		local clientCloseCode: number? = nil
		local clientCloseReason: string? = nil
		local serverCloseCode: number? = nil
		local serverCloseMessage: string? = nil
		local firstServerSendResult: number? = nil

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

		local _ws: client.WebSocket?
		_ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if _ws then
					_ws:send("hello")
				end
			end,
			onmessage = function(message)
				if type(message) == "string" and message == "hello" then
					receivedEcho = true
					if _ws then
						_ws:send("bye")
					end
				end
			end,
			onclose = function(code, reason)
				clientClosed = true
				clientCloseCode = code
				clientCloseReason = reason
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
		if clientCloseCode == nil or clientCloseReason == nil then
			error("client close callback did not capture close details")
		end
		if firstServerSendResult == nil then
			error("server send result was not captured")
		end
		if serverCloseCode == nil or serverCloseMessage == nil then
			error("websocket close callback did not run")
		end
		assert.eq(true, firstServerSendResult > 0)
		assert.eq(4001, clientCloseCode)
		assert.eq("done", clientCloseReason)
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
		local _ws: client.WebSocket?
		_ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if _ws then
					_ws:send(payload)
				end
			end,
			onmessage = function(message)
				if type(message) ~= "buffer" then
					error("expected binary websocket message")
				end
				clientSawBinary = true
				local messageBuffer: buffer = message
				assert.eq(payload, messageBuffer)

				if _ws then
					_ws:close()
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

	suite:case("serveWebsocketYieldedMessageHandler", function(assert)
		local serverStarted = false
		local serverResumed = false
		local sendResult: number? = nil
		local receivedEcho = false
		local closed = false

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
					serverStarted = true
					task.wait()
					serverResumed = true
					sendResult = ws:send(`yielded:{message}`)
				end,
			},
		})

		local _ws: client.WebSocket?
		_ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if _ws then
					_ws:send("hello")
				end
			end,
			onmessage = function(message)
				if type(message) == "string" and message == "yielded:hello" then
					receivedEcho = true
					if _ws then
						_ws:close()
					end
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
		while (not receivedEcho or not closed or not serverResumed) and os.clock() - start < 5 do
			task.deferSelf()
		end

		assert.eq(true, serverStarted)
		assert.eq(true, serverResumed)
		assert.eq(true, receivedEcho)
		assert.eq(true, closed)
		if sendResult == nil then
			error("yielded server send result was not captured")
		end
		assert.eq(true, sendResult > 0)

		instance.close()
	end)

	suite:case("clientWebsocketCallbacksSurviveGc", function(assert)
		local opened = false

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
			websocket = {},
		})

		local _ws: client.WebSocket?
		_ws = client.websocket(`ws://{instance.hostname}:{instance.port}`, {
			onopen = function()
				if _ws then
					_ws:close()
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

	suite:case("serverCloseIsIdempotent", function(assert)
		local instance = server.serve({
			port = 0,
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				return "ok"
			end,
		})

		assert.eq(true, instance.close())
		assert.eq(false, instance.close())
	end)

	suite:case("serveStringResponsePreservesNulBytes", function(assert)
		local body = "a\0b"
		local instance = server.serve({
			port = 0,
			handler = function(_req: server.ReceivedRequest): server.ServerResponse
				return body
			end,
		})

		local response = client.request(`{instance.hostname}:{instance.port}`)
		assert.eq(true, response.ok)
		assert.eq(200, response.status)
		assert.eq(3, #response.body)
		assert.eq(body, response.body)

		instance.close()
	end)
end)
