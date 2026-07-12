# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
```

## Credential resolution

GitHub requests resolve credentials in this order:

1. Environment variable: `GITHUB_TOKEN`
2. Credentials saved by `lute pkg auth`
3. User-configured credential resolver

If none of these returns a token, Lute performs the request without authentication.

Credential resolvers are configured in `~/.lute/config.luau`. This is a trusted,
user-owned configuration file; project `loom.config.luau` files cannot provide
credential resolvers.

```luau
local process = require("@std/process")
local stringext = require("@std/stringext")

return {
	credentialResolvers = {
		["github.com"] = function(request)
			local result = process.run({
				"gh",
				"auth",
				"token",
				"--hostname",
				request.host,
			})
			return if result.ok then stringext.trim(result.stdout) else nil
		end,
	},
}
```

Resolver functions receive a `CredentialRequest` containing `protocol`, `host`,
and an optional repository `path`. A resolver returns a token string, or `nil`
when no credential is available. A resolver registered under `"*"` is used when
no host-specific resolver is configured.

Returning `nil` permits an unauthenticated request. Resolver errors propagate to
the caller.
