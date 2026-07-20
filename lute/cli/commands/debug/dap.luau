local dapStream = require("./dapStream")

local function dapLoop(reader: dapStream.Reader, writer: dapStream.Writer)
	local ioSession = dapStream.makeDapStreamSession(reader, writer)
	while true do
		local request = ioSession.readDap()
		local command = request.command :: string
		local reqSeq = request.seq :: number
		if command == "initialize" then
			ioSession.writeResponse(reqSeq, true, command)
			ioSession.writeEvent("initialized")
		elseif command == "configurationDone" then
			ioSession.writeResponse(reqSeq, true, command)
		elseif command == "terminate" or command == "disconnect" then
			ioSession.writeResponse(reqSeq, true, command)
			break
		elseif command == "launch" then
			ioSession.writeResponse(reqSeq, true, command)
		else
			ioSession.writeResponse(reqSeq, false, command, `unsupported command: {command}`)
		end
	end
end

return {
	dapLoop = dapLoop,
}
