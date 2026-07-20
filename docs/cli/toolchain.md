---
order: 9
---

# toolchain

Project-local toolchain management via `.config.luau`.

When the invoked `lute` detects a version pin in `.config.luau`, it automatically downloads the pinned binary if needed, and re-execs to it.

The `lute self` and `lute toolchain` commands always run on the invoked binary.

## Config

Add a `lute.toolchain.lute` field to your project's `.config.luau`:

```luau
return {
	lute = {
		toolchain = {
			lute = "v1.0.0",
		},
	},
}
```
