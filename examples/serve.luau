local net = require("@lute/net")

print("Starting server...")

-- Start the server (non-blocking)
local server = net.serve(function(req)
	return "Hello, lute!"
end)

print(`Server listening on http://{server.hostname}:{server.port}`)

print("Program ending, but server will continue running in the background")

-- If you want to close the server:
-- server.close()
