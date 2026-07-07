local io = require("@std/io")
local json = require("@std/json")

local readBuf = ""
local writeSeqNum = 1

local function readDap(): json.Object
	while not readBuf:find("\r\n\r\n") do
		readBuf ..= io.input()
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
		readBuf ..= io.input()
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
		seq = writeSeqNum,
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
	writeSeqNum += 1

	local encoded = json.serialize(response)
	io.write(`Content-Length: {#encoded}\r\n\r\n{encoded}`)
end

local function writeEvent(event: string, body: json.Object?)
	local msg: json.Object = {
		seq = writeSeqNum,
		type = "event",
		event = event,
	}
	if body then
		msg.body = body
	end
	writeSeqNum += 1

	local encoded = json.serialize(msg)
	io.write(`Content-Length: {#encoded}\r\n\r\n{encoded}`)
end

local function dapLoop()
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
        else
            writeResponse(seq, false, command, `unsupported command: {command}`)
        end
    end
end
