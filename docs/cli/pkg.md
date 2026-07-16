# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
```

## Package-source authentication

Lute authenticates GitHub package downloads by checking these sources in order:

1. The `GITHUB_TOKEN` environment variable.
2. A user-defined credential provider in `~/.lute/config.luau`.
3. The plaintext auth store at `~/.loom/auth.luau` (managed via `lute pkg auth`).

If no token is found, Lute proceeds without authentication.

Credential providers live in `~/.lute/config.luau`, a Luau module with full access to `@std` libraries. Entries map an explicit host to a function. Prefer secure helpers (for example `gh`) over plaintext tokens.

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

Provider functions receive a `CredentialRequest` with `protocol`, `host`, and an optional repository `path`. Return a token string, or `nil` to fall through to the plaintext store / unauthenticated request. Provider errors propagate to the caller.
