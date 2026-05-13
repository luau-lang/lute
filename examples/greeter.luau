local io = require("@lute/io")
local process = require("@lute/process")

process.onSignal("SIGINT", function()
	print("\nOh, goodbye then!")
	process.exit(0)
end)

while true do
	io.write("What's your name? ")
	local name = io.read():gsub("\r?\n$", "")
	print(`Hi, {name}!`)
end
