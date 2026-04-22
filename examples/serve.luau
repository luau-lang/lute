local server = require("@lute/net/server")

print("Starting server...")

-- Start the server (non-blocking)
local instance = server.serve(function(_)
	return "Hello, lute!"
end)

print(`Server listening on http://{instance.hostname}:{instance.port}`)

print("Program ending, but server will continue running in the background")

-- If you want to close the server:
-- server.close()
