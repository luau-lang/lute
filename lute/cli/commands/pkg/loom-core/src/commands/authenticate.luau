local cli = require("@batteries/cli")
local authStore = require("../authentication")

local function authenticate(...: string)
	local args = cli.parser()
	args:add("token", "option", { help = "Authentication token", required = true })
	args:add("domain", "option", { help = "Domain to authenticate with", default = "github.com" })
	args:parse({ ... })

	local token = args:get("token")
	if not token then
		error("Usage: `lute pkg auth --token <token> [--domain <domain>]`")
	end

	local domain = args:get("domain") or "github.com"
	authStore.saveAuthenticationToken(domain, token)
end

return authenticate
