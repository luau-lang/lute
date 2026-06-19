local cli = require("@batteries/cli")
local fs = require("@std/fs")
local keyring = require("@lute/keyring")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

local KEYRING_SERVICE = "loom"

local USAGE = [[Usage: lute pkg auth <action> [options]

Manage loom's authentication credentials in the OS-native credential
store (Keychain on macOS, Credential Manager on Windows).

Actions:
  add --token <token> [--domain <domain>]   Store a credential
  remove              [--domain <domain>]   Remove a stored credential
  migrate                                   Move legacy plaintext credentials
                                            from ~/.loom/auth.luau into the keyring
]]

local function readAndDeleteLegacyTokens(): { read { read domain: string, read token: string } }
	local tokens: { { read domain: string, read token: string } } = {}

	local authPath = path.join(process.homedir(), ".loom", "auth.luau")
	if not fs.exists(authPath) then
		return table.freeze(tokens)
	end

	local ok, result = pcall(luau.loadModule, authPath, nil)
	if not ok or typeof(result) ~= "table" then
		return table.freeze(tokens)
	end

	pcall(fs.remove, authPath)

	for key, value in result do
		if typeof(key) == "string" and typeof(value) == "table" and typeof(value.token) == "string" then
			table.insert(tokens, table.freeze({ domain = key, token = value.token }))
		end
	end
	return table.freeze(tokens)
end

local function add(args: { string })
	local parsed = cli.parser()
	parsed:add("token", "option", { help = "Authentication token", required = true })
	parsed:add("domain", "option", { help = "Domain to authenticate with", default = "github.com" })
	parsed:parse(args)

	local token = parsed:get("token") :: string
	local domain = parsed:get("domain") :: string
	keyring.set(KEYRING_SERVICE, domain, token)

	print(`Credential added for {domain}`)
end

local function remove(args: { string })
	local parsed = cli.parser()
	parsed:add("domain", "option", { help = "Domain to remove", default = "github.com" })
	parsed:parse(args)

	local domain = parsed:get("domain") :: string
	keyring.delete(KEYRING_SERVICE, domain)

	print(`Credential removed for {domain}`)
end

local function migrate()
	local tokens = readAndDeleteLegacyTokens()
	if #tokens == 0 then
		print("No legacy credentials to migrate")
		return
	end

	print(`Migrated {#tokens} credential(s) to OS credential store:`)
	for _, entry in tokens do
		print(`  {entry.domain}`)
	end
end

local function authenticate(...: string)
	local args = { ... }
	if #args == 0 or table.find(args, "-h") ~= nil or table.find(args, "--help") ~= nil then
		print(USAGE)
		return
	end

	if not keyring.isSupported() then
		error("OS credential store is not supported on this platform.")
	end

	local action = args[1]
	table.remove(args, 1)
	table.freeze(args)

	if action == "add" then
		add(args)
	elseif action == "remove" then
		remove(args)
	elseif action == "migrate" then
		migrate()
	else
		error(`Unknown action: {action}\n\n{USAGE}`)
	end
end

return authenticate
