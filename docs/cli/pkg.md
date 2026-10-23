# pkg

Manage dependencies declared in `loom.config.luau`.

## Usage

```bash
lute pkg install
lute pkg publish [--dry-run]
```

## Publishing

Run `lute pkg publish` from a package directory to publish that package. 

Publishing evaluates `loom.config.luau`, then writes a generated, normalized `loom.config.luau` into the ZIP. The generated manifest flattens the values into the evaluated values rather than the original `require` expressions, and its production path and GitHub dependencies are converted to registry dependencies when they declare a version constraint. For example:

```luau
dependencies = {
	shared = { name = "acme/shared", sourceKind = "path", source = "../shared", version = "^2.0.0" },
}
```

is published as:

```luau
dependencies = {
	shared = { sourceKind = "registry", source = "acme/shared", version = "^2.0.0" },
}
```

Production path and GitHub dependencies without a version constraint are unsupported and cause publishing to fail. Development dependencies are retained without conversion. Virtual packages, which have no package name or version, cannot be published. The original manifest on disk is not modified.

### Package files

The ZIP contains files gathered from `content_root`, or from the package directory when `content_root` is not set. The `files` field filters those files using gitignore-style glob patterns. Patterns are relative to the content root and are applied in order; the last matching pattern determines whether a path is included.

In addition to common glob patterns the following is the behavior of files:
- A normal pattern includes matching files; a pattern prefixed with `!` excludes them.
- If at least one normal pattern is present, files that do not match any pattern are excluded. If `files` contains only `!` patterns, unmatched files are included.
- Hidden files and directories are excluded unless a positive `files` pattern explicitly includes them. `.gitignore` does not affect the archive.
- The source `loom.config.luau` is included as `loom.config.luau.orig`, preventing it from colliding with the generated manifest at `loom.config.luau`.
- Symlinks in the package source are not supported.

Use `--dry-run` to validate the manifest and build the ZIP in memory without uploading it. This does not require a registry or credentials and does not write an archive to disk.

Uploads use the `registry` in the package's manifest. Publishing requires an Artifactory token, resolved in this order: `LOOM_ARTIFACTORY_TOKEN`, a configured credential provider, then the auth store managed by `lute pkg auth --domain <registry-host> --token <token>`. The ZIP is sent to `<registry>/api/v1/publish`.

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
