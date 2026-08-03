local authenticationStore = require("../authenticationstore")
local cli = require("@batteries/cli")

local function authenticate(...: string)
	local args = cli.parser()
	args:add("token", "option", { help = "Authentication token", required = true })
	args:add("domain", "option", { help = "Domain to authenticate with", default = "github.com" })

	local valid, err = pcall(cli.parse, args, { ... })
	if not valid then
		print(err)
		args:help()
		error(err)
	end

	local token = args:get("token")
	local domain = args:get("domain") or "github.com"
	authenticationStore.saveAuthenticationToken(domain, token)
end

return authenticate
