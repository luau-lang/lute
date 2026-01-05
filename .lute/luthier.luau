--!strict

local process = require("@lute/process")

local args = table.pack(...)

local cmd = { process.execpath(), "tools/luthier.luau", table.unpack(args, 2, args.n) }

local result = process.run(cmd, { stdio = "inherit" })
process.exit(result.exitcode)
