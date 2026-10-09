# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
lute pkg publish [--package <member-name>] [--dry-run]
```

## Publishing

Run `lute pkg publish` from a package directory to publish that package. At a workspace root with multiple packages, select one by its package name using `--package <member-name>`.

Publishing evaluates `loom.config.luau`, including values inherited through `require`, and builds a ZIP containing the package files and a generated, flattened `loom.config.luau`. Production path and GitHub dependencies must declare a version constraint so they can be converted to registry dependencies. Development dependencies are retained. The original manifest is not modified.

Use `--dry-run` to validate the manifest and build the ZIP in memory without uploading it. This does not require a registry or credentials and does not write an archive to disk.

Uploads use the `registry` in the package's manifest, or the workspace root's manifest for workspace members. Publishing requires an Artifactory token, resolved in this order: `LOOM_ARTIFACTORY_TOKEN`, a configured credential provider, then the auth store managed by `lute pkg auth --domain <registry-host> --token <token>`. The ZIP is sent to `<registry>/api/v1/publish`.

## Package-source authentication

Lute authenticates GitHub package downloads by checking these sources in order:

1. The `GITHUB_TOKEN` environment variable.
2. A credential provider configured in `.config.luau`.
3. The plaintext auth store at `~/.loom/auth.luau` (managed via `lute pkg auth`).

If no token is found, Lute proceeds without authentication.

### Configuring credential providers

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
