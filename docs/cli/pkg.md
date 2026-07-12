# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
```

## Credential resolution

GitHub credentials are discovered in the following order:

1. `GITHUB_TOKEN` environment variable
2. User-defined credential resolver hook (`~/.lute/config.luau`)
3. Plaintext auth store (`~/.loom/auth.luau` via `lute pkg auth`)

If none of these returns a token, Lute performs the request without authentication.

Credential resolvers are configured in `~/.lute/config.luau`. This is a trusted, user-owned configuration file.

```luau
local process = require("@std/process")
local stringext = require("@std/stringext")

return {
	auth = {
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

Resolver functions receive a `CredentialRequest` containing `protocol`, `host`, and an optional repository `path`. A resolver returns a token string, or `nil` when no credential is available. A resolver registered under `"*"` is used when no host-specific resolver is configured.

Returning `nil` permits an unauthenticated request. Resolver errors propagate to the caller.
