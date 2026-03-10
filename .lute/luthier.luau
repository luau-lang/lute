--!strict

local process = require("@lute/process")

-- LUAUFIX: should `...` actually have the type `string...` for command-line environments
local args: { [number]: string, n: number } = table.pack(...) :: any

local cmd: {string} = { process.execpath(), "tools/luthier.luau", table.unpack(args, 2, args.n) }

local result = process.run(cmd, { stdio = "inherit" })
process.exit(result.exitcode)
