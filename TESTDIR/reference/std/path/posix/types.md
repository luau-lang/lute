# types

```luau
local types = require("@std/path/posix/types")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [Path](#path) | A structured POSIX path. |
| [PathData](#pathdata) | The raw data of a POSIX path: an array of components and a flag indicating whether the path is absolute. |
| [Pathlike](#pathlike) | Anything that can be used as a POSIX path: a string, a `Path`, or raw `PathData`. |

---

## Types

### Path

A structured POSIX path.

```luau
type Path = setmetatable<PathData, pathinterface.PathInterface>
```

---

### PathData

The raw data of a POSIX path: an array of components and a flag indicating whether the path is absolute.

```luau
type PathData = {
	parts: { string },
	absolute: boolean,
}
```

---

### Pathlike

Anything that can be used as a POSIX path: a string, a `Path`, or raw `PathData`.

```luau
type Pathlike = string | Path | PathData
```

---
