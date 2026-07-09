local json = require("@std/json")

-- we want generic Reader/Writer functions to easily test + support
-- different transport mechanisms
type Reader = (string?) -> string
type Writer = (string) -> ()

local function dapLoop(reader: Reader, writer: Writer)
	local readBuf = ""
	local seqNum = 1

	local function readDap(): json.Object
		while not readBuf:find("\r\n\r\n") do
			readBuf ..= reader()
		end

		-- the header for a DAP request will always be of the form
		-- "Content-Length: 119\r\n\r\n"
		local headerEnd = readBuf:find("\r\n\r\n")
		assert(headerEnd, "missing \r\n\r\n when reading")
		local header = readBuf:sub(1, headerEnd - 1)
		local contentLength = tonumber(header:match("Content%-Length: (%d+)"))
		assert(contentLength, "missing Content-Length in protocol read")
		readBuf = readBuf:sub(headerEnd + 4)

		while #readBuf < contentLength do
			readBuf ..= reader()
		end

		local body = readBuf:sub(1, contentLength)
		local deserialized = json.deserialize(body)
		deserialized = assert(json.asObject(deserialized), "incoming protocol read could not be deserialized")

		readBuf = readBuf:sub(contentLength + 1)
		return deserialized
	end

	local function writeResponse(
		requestSeq: number,
		success: boolean,
		command: string,
		message: string?,
		body: json.Object?
	)
		local response: json.Object = {
			seq = seqNum,
			type = "response",
			request_seq = requestSeq,
			success = success,
			command = command,
		}
		if message then
			response.message = message
		end
		if body then
			response.body = body
		end
		seqNum += 1

		local encoded = json.serialize(response)
		writer(`Content-Length: {#encoded}\r\n\r\n{encoded}`)
	end

	local function writeEvent(event: string, body: json.Object?)
		local msg: json.Object = {
			seq = seqNum,
			type = "event",
			event = event,
		}
		if body then
			msg.body = body
		end
		seqNum += 1

		local encoded = json.serialize(msg)
		writer(`Content-Length: {#encoded}\r\n\r\n{encoded}`)
	end

	while true do
		local request = readDap()
		local command = request.command :: string
		local seq = request.seq :: number
		if command == "initialize" then
			writeResponse(seq, true, command)
			writeEvent("initialized")
		elseif command == "configurationDone" then
			writeResponse(seq, true, command)
		elseif command == "terminate" or command == "disconnect" then
			writeResponse(seq, true, command)
			break
		elseif command == "launch" then
			writeResponse(seq, true, command)
		else
			writeResponse(seq, false, command, `unsupported command: {command}`)
		end
	end
end

return {
	dapLoop = dapLoop,
}
