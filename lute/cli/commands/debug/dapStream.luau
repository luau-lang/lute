local json = require("@std/json")

-- we want generic Reader/Writer functions to easily test + support
-- different transport mechanisms
export type Reader = (string?) -> string
export type Writer = (string) -> ()

local function makeDapStreamSession(reader: Reader, writer: Writer)
	local readBuf = ""
	local seqNum = 1

	-- because we are getting chunks of input, we want to pass in the readBuf of the
	-- previous successful call into the next call
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
		local encoded = json.serialize(response)
		writer(`Content-Length: {#encoded}\r\n\r\n{encoded}`)
		seqNum = seqNum + 1
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
		local encoded = json.serialize(msg)
		writer(`Content-Length: {#encoded}\r\n\r\n{encoded}`)
		seqNum = seqNum + 1
	end

	return {
		readDap = readDap,
		writeResponse = writeResponse,
		writeEvent = writeEvent,
	}
end

return {
	makeDapStreamSession = makeDapStreamSession,
}
