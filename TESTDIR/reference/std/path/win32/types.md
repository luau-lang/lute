# types

```luau
local types = require("@std/path/win32/types")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Path](#path) | A structured Windows path. |
| [PathData](#pathdata) | The raw data of a Windows path: an array of components, the path kind, and an optional drive letter. |
| [PathKind](#pathkind) | Describes how a Windows path is rooted: |
| [Pathlike](#pathlike) | Anything that can be used as a Windows path: a string, a `Path`, or raw `PathData`. |

---

## Types

### Path

A structured Windows path.

```luau
type Path = setmetatable<PathData, pathinterface.PathInterface>
```

---

### PathData

The raw data of a Windows path: an array of components, the path kind, and an optional drive letter.

```luau
type PathData = {
	parts: { string },
	kind: PathKind,
	drive: string?,
}
```

---

### PathKind

Describes how a Windows path is rooted:

- `"absolute"`: Drive-rooted path, e.g. `C:\foo`.

- `"unc"`: UNC path, e.g. `\\server\share`.

- `"relative"`: A path with no drive or UNC root.

```luau
type PathKind = "unc" | "absolute" | "relative"
```

---

### Pathlike

Anything that can be used as a Windows path: a string, a `Path`, or raw `PathData`.

```luau
type Pathlike = string | PathData | Path
```

---
