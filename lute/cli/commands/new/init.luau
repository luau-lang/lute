local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local typedefs = require("./lib/typedefs")

local function printHelp(args: cli.Parser)
	print(args:usage("lute new"))
	print("\nCreate a new Lute project with a standard directory layout.\n")
	print(args:help())
	print([[

EXAMPLES:
  lute new myproject
]])
end

local function main(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("project-name", "positional", { help = "Name of the project to create" })
	args:parse({ ... })

	if args:has("help") then
		printHelp(args)
		return
	end

	local projectName = args:get("project-name")
	if projectName == nil or projectName == "" then
		print(`Error: Missing required argument <project-name>.\n\n{args:usage("lute new")}\nUse --help for more information.`)
		process.exit(1)
	end

	-- LUAUFIX - refinements aren't correctly being applied here.
	-- At this point, we should know that ~ (projectName == nil or projectName == "") is true (which should imply that projectName ~= nil)
	assert(projectName)
	local projectPath = path.join(process.cwd(), projectName)

	if fs.exists(projectPath) then
		print(`Error: Directory '{projectName}' already exists.`)
		process.exit(1)
	end

	if not fs.exists(typedefs.TYPEDEFS_PATH) then
		print("Running lute setup first...")
		local result = process.run({ path.format(process.execPath()), "setup" }, { stdio = "inherit" })
		if not result.ok then
			print("Error: lute setup failed.")
			process.exit(1)
		end
	end

	fs.createDirectory(projectPath)

	local mainScript = path.join(projectPath, "main.luau")
	local testScript = path.join(projectPath, "main.test.luau")

	fs.writeStringToFile(
		mainScript,
		[[print("Hello, world!")
]]
	)

	fs.writeStringToFile(
		testScript,
		[[local _test = require("@std/test")
]]
	)

	fs.writeStringToFile(path.join(projectPath, ".config.luau"), typedefs.generateConfigDotLuau("strict"))

	print(`Created project '{projectName}'`)
	print("")
	print("To get started:")
	print(`\tcd {projectName}`)
	print("\tlute run main.luau")
	print("\tlute test")
end

main(...)
