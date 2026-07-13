# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
```

## Authentication resolution

The GitHub token is discovered in the following order:

1. `GITHUB_TOKEN` environment variable
2. User-defined credential provider (`~/.lute/config.luau`)
3. Plaintext auth store (`~/.loom/auth.luau` via `lute pkg auth`)

If none of these returns a token, Lute performs the request without authentication.

Credential providers are configured in `~/.lute/config.luau`. This is a standard Luau module with full access to `@std` libraries.

```luau
local process = require("@std/process")
local stringext = require("@std/stringext")

return {
	credentials = {
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

Provider functions receive an `CredentialRequest` containing `protocol`, `host`, and an optional repository `path`. A provider returns a token string, or `nil` when no token is available. A provider registered under `"*"` is used when no host-specific provider is configured.

Returning `nil` permits an unauthenticated request. Provider errors propagate to the caller.
