# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
```

## Authentication token resolution

Lute resolves the GitHub authentication token by checking the following sources in order of precedence:

1. The `GITHUB_TOKEN` environment variable.
2. A user-defined credential provider in `~/.lute/config.luau`.
3. The plaintext auth store at `~/.loom/auth.luau` (managed via `lute pkg auth`).

If no token is found, Lute proceeds with the request without authentication.

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
