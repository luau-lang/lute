local test = require("@std/test")
local json = require("@std/json")
local dapStream = require("../../lute/cli/commands/debug/dap")
local path = require("@std/path")
local process = require("@std/process")

local lutePath = path.format(process.execPath())
local USAGE = "Usage: lute debug serve"

local function normalizePath(p: string): string
	return (p:gsub("\\", "/"))
end

local function makeMessage(obj: { [string]: any }): string
	local body = json.serialize(obj)
	return `Content-Length: {#body}\r\n\r\n{body}`
end

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

test.suite("LuteDebug", function(suite)
	-- tests specifically for DAP Stream I/O
	suite:case("luteDebugDAPStream", function(assert)
		local inMsg1 = makeMessage({
			seq = 1,
			type = "request",
			command = "initialize",
			arguments = { clientID = "test", adapterID = "lute" },
		})
		local inMsg2 = makeMessage({ seq = 2, type = "request", command = "configurationDone" })
		local inMsg3 =
			makeMessage({ seq = 3, type = "request", command = "launch", arguments = { program = "/test.luau" } })
		local inMsg4 = makeMessage({ seq = 4, type = "request", command = "terminate" })
		local input = inMsg1 .. inMsg2 .. inMsg3 .. inMsg4
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
			assert.eq(msg4.success, false)
			assert.eq(msg4.request_seq, 3)
			assert.eq(msg4.seq, 4)

			local msg5, rest5 = parseJsonMessage(rest4)
			assert.eq(msg5.type, "response")
			assert.eq(msg5.command, "terminate")
			assert.eq(msg5.success, true)
			assert.eq(msg5.request_seq, 4)
			assert.eq(msg5.seq, 5)

			local msg6, _ = parseJsonMessage(rest5)
			assert.eq(msg6.type, "event")
			assert.eq(msg6.event, "terminated")
		end

		-- check for multiple different block sizes of the reader
		local reader = makeChunkReader(input, 16)
		local write, getWritten, clear = makeWriter()
		dapStream.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, 7)
		clear()
		dapStream.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, 4)
		clear()
		dapStream.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, 2)
		clear()
		dapStream.dapLoop(reader, write)
		checkEquivalence(getWritten())

		reader = makeChunkReader(input, #input)
		clear()
		dapStream.dapLoop(reader, write)
		checkEquivalence(getWritten())
	end)
	-- tests DAP setBreakpoints and loadedSources
	suite:case("luteDebugBreakpointsSources", function(assert)
		local fixturePath = path.format(path.join(process.cwd(), "tests/src/debug/loop.luau"))
		local inMsg1 = makeMessage({
			seq = 1,
			type = "request",
			command = "initialize",
			arguments = { clientID = "test", adapterID = "lute" },
		})
		local inMsg2 = makeMessage({
			seq = 2,
			type = "request",
			command = "setBreakpoints",
			arguments = { source = { path = fixturePath }, breakpoints = { { line = 4 } } },
		})
		local inMsg3 = makeMessage({ seq = 3, type = "request", command = "configurationDone" })
		local inMsg4 =
			makeMessage({ seq = 4, type = "request", command = "launch", arguments = { program = fixturePath } })
		local inMsg5 = makeMessage({ seq = 5, type = "request", command = "loadedSources" })
		local inMsg6 = makeMessage({ seq = 6, type = "request", command = "terminate" })
		local input = inMsg1 .. inMsg2 .. inMsg3 .. inMsg4 .. inMsg5 .. inMsg6

		local write, getWritten, _ = makeWriter()
		dapStream.dapLoop(makeChunkReader(input, #input), write)
		local written = getWritten()

		local msg1, rest1 = parseJsonMessage(written)
		assert.eq(msg1.command, "initialize")
		assert.eq(msg1.success, true)

		local msg2, rest2 = parseJsonMessage(rest1)
		assert.eq(msg2.event, "initialized")

		local msg3, rest3 = parseJsonMessage(rest2)
		assert.eq(msg3.command, "setBreakpoints")
		assert.eq(msg3.success, true)
		local bpBody = msg3.body :: json.Object
		local bps = json.asArray(bpBody.breakpoints) :: json.Array
		assert.that(bps ~= nil)
		assert.eq(#bps, 1)
		local bp = json.asObject(bps[1]) :: json.Object
		assert.that(bp ~= nil)
		assert.eq(bp.verified, false)
		assert.eq(bp.line, 4)
		assert.eq(bp.reason, "pending")

		local msg4, rest4 = parseJsonMessage(rest3)
		assert.eq(msg4.command, "configurationDone")
		assert.eq(msg4.success, true)

		local msg5, rest5 = parseJsonMessage(rest4)
		assert.eq(msg5.command, "launch")
		assert.eq(msg5.success, true)

		local msg6, rest6 = parseJsonMessage(rest5)
		assert.eq(msg6.command, "loadedSources")
		assert.eq(msg6.success, true)
		local srcBody = msg6.body :: json.Object
		local sources = json.asArray(srcBody.sources) :: json.Array
		assert.that(sources ~= nil)
		assert.eq(#sources, 1)
		local source = json.asObject(sources[1]) :: json.Object
		assert.that(source ~= nil)
		assert.eq(source.path, normalizePath(fixturePath))
		assert.eq(source.name, "loop.luau")

		local msg7, rest7 = parseJsonMessage(rest6)
		assert.eq(msg7.command, "terminate")
		assert.eq(msg7.success, true)

		local msg8, _ = parseJsonMessage(rest7)
		assert.eq(msg8.event, "terminated")
	end)
	-- tests specifically for DAP unknown format
	suite:case("luteDebugUnknown", function(assert)
		local inMsg1 = makeMessage({
			seq = 1,
			type = "request",
			command = "bad",
		})
		local inMsg2 = makeMessage({
			seq = 2,
			type = "request",
			command = "disconnect",
		})
		local input = inMsg1 .. inMsg2
		local write, getWritten, _ = makeWriter()
		dapStream.dapLoop(makeChunkReader(input, #input), write)
		local written = getWritten()

		local msg1, rest1 = parseJsonMessage(written)
		assert.eq(msg1.type, "response")
		assert.eq(msg1.command, "bad")
		assert.eq(msg1.message, "unsupported command: bad")
		assert.eq(msg1.success, false)

		local msg2, rest2 = parseJsonMessage(rest1)
		assert.eq(msg2.type, "response")
		assert.eq(msg2.command, "disconnect")
		assert.eq(msg2.success, true)

		local msg3, _ = parseJsonMessage(rest2)
		assert.eq(msg3.type, "event")
		assert.eq(msg3.event, "terminated")
	end)
	suite:case("luteDebugHelpMessage", function(assert)
		local result = process.run({ lutePath, "debug", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)

		result = process.run({ lutePath, "debug", "--h" })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)

		result = process.run({ lutePath, "debug", "--help" })
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)
	end)
end)
