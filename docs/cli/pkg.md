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
3. The `github.com` entry in the plaintext auth store at `~/.loom/auth.luau` (managed via `lute pkg auth`).

If no token is found, Lute proceeds without authentication.

## Package-registry authentication

Registry credentials are scoped to the registry host. When a credential is available, Lute sends it on both package reads and publishes as an HTTP Bearer token. When none is configured, Lute omits the `Authorization` header, allowing registries that permit anonymous access to handle the request.

Save a credential for a registry with:

```bash
lute pkg auth --domain registry.example.com --token "$REGISTRY_TOKEN"
```

Lute resolves registry credentials by checking a configured credential provider and then the plaintext auth store at `~/.loom/auth.luau`, managed by `lute pkg auth`. This allows credentials for multiple registries to coexist.

## Configuring credential providers

Credential providers can supply tokens for either package sources or package registries.

Add a `credentials` table to your project's `.config.luau`. The `providers` field is an array of paths, each pointing to a credential provider module:

```luau
return {
	lute = {
		credentials = {
			providers = { "./credentials/github.luau" }
		}
	}
}
```

Lute walks up the directory tree from the working directory to find the nearest `.config.luau` containing this field. Each path is resolved relative to the config file's location.

Each listed `.luau` file is a credential provider module with full access to `@std` libraries. Prefer secure helpers (for example `gh`) over plaintext tokens.

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
