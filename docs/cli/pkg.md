# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
```

## Package-source authentication

Lute authenticates GitHub package downloads by checking these sources in order:

1. The `GITHUB_TOKEN` environment variable.
2. A credential provider configured in `.config.luau`.
3. The plaintext auth store at `~/.loom/auth.luau` (managed via `lute pkg auth`).

If no token is found, Lute proceeds without authentication.

### Configuring credential providers

Add a `credentials` table to your project's `.config.luau`:

```luau
return {
	lute = {
		credentials = {
			providers = "./credentials"
		}
	}
}
```

Lute walks up the directory tree from the working directory to find the nearest `.config.luau` containing this field. The path is resolved relative to the config file's location.

Each `.luau` file in the directory is a credential provider module with full access to `@std` libraries. Prefer secure helpers (for example `gh`) over plaintext tokens.

```luau
-- credentials/github.luau
local process = require("@std/process")
local stringext = require("@std/stringext")

return {
	host = "github.com",
	resolve = function(request)
		local result = process.run({ "gh", "auth", "token" "--hostname", request.host })
		return if result.ok then stringext.trim(result.stdout) else nil
	end,
}
```

Provider `resolve` functions receive a request with `protocol`, `host`, and an optional repository `path`. Return a token string, or `nil` to fall through to the plaintext store / unauthenticated request. Provider errors propagate to the caller.
