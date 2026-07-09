local test = require("@std/test")
local json = require("@std/json")
local dap = require("../../lute/cli/commands/debug/dap")

local function makeChunkReader(readMessage: string, blockSize: number)
	local pos = 1
	return function()
		local chunk = readMessage:sub(pos, pos + blockSize - 1)
		pos += blockSize
		return chunk
	end
end

local function makeWriter()
	local written = ""
	local function write(message: string)
		written ..= message
	end
	local function getWritten()
		return written
	end
	local function clear()
		written = ""
	end
	return write, getWritten, clear
end

local function parseJsonMessage(msg: string): (json.Object, string)
	local headerEnd = assert(msg:find("\r\n\r\n"), "missing \\r\\n\\r\\n") :: number
	local header = msg:sub(1, headerEnd - 1)
	local contentLength = assert(tonumber(header:match("Content%-Length: (%d+)")), "missing Content-Length") :: number
	local body = msg:sub(headerEnd + 4, headerEnd + 3 + contentLength)
	local remaining = msg:sub(headerEnd + 4 + contentLength)
	return assert(json.asObject(json.deserialize(body)), "body is not a JSON object"), remaining
end

test.suite("LuteDap", function(suite)
	suite:case("basicInitializationTermination", function(assert)
		local input = 'Content-Length: 100\r\n\r\n{"seq":1,"type":"request","command":"initialize","arguments":{"clientID":"test","adapterID":"lute"}}'
			.. 'Content-Length: 56\r\n\r\n{"seq":2,"type":"request","command":"configurationDone"}'
			.. 'Content-Length: 45\r\n\r\n{"seq":3,"type":"request","command":"launch"}'
			.. 'Content-Length: 48\r\n\r\n{"seq":4,"type":"request","command":"terminate"}'

		local function checkEquivalence(written: string)
			local msg1, rest1 = parseJsonMessage(written)
			assert.eq(msg1.type, "response")
			assert.eq(msg1.command, "initialize")
			assert.eq(msg1.success, true)
			assert.eq(msg1.request_seq, 1)
			assert.eq(msg1.seq, 1)

			local msg2, rest2 = parseJsonMessage(rest1)
			assert.eq(msg2.type, "event")
			assert.eq(msg2.event, "initialized")
			assert.eq(msg2.seq, 2)

			local msg3, rest3 = parseJsonMessage(rest2)
			assert.eq(msg3.type, "response")
			assert.eq(msg3.command, "configurationDone")
			assert.eq(msg3.success, true)
			assert.eq(msg3.request_seq, 2)
			assert.eq(msg3.seq, 3)

			local msg4, rest4 = parseJsonMessage(rest3)
			assert.eq(msg4.type, "response")
			assert.eq(msg4.command, "launch")
			assert.eq(msg4.success, true)
			assert.eq(msg4.request_seq, 3)
			assert.eq(msg4.seq, 4)

			local msg5, _ = parseJsonMessage(rest4)
			assert.eq(msg5.type, "response")
			assert.eq(msg5.command, "terminate")
			assert.eq(msg5.success, true)
			assert.eq(msg5.request_seq, 4)
			assert.eq(msg5.seq, 5)
		end

		-- check for multiple different block sizes of the reader
		local reader = makeChunkReader(input, 16)
		local write, getWritten, clear = makeWriter()
		dap.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, 7)
		clear()
		dap.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, 4)
		clear()
		dap.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, 2)
		clear()
		dap.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, #input)
		clear()
		dap.dapLoop(reader, write)
		checkEquivalence(getWritten())
	end)
end)
