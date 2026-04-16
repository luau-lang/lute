# win32

```luau
local win32 = require("@std/path/win32")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [Path](#path) |  |
| [PathKind](#pathkind) |  |
| [Pathlike](#pathlike) |  |
| [basename](#win32basename) | Returns the last component of `path`, or `nil` if the path has no components. |
| [dirname](#win32dirname) | Returns the directory portion of `path` as a string (everything except the last component). |
| [drive](#win32drive) | Returns a `Path` representing just the drive root of `path` (e.g. `C:\`). Errors if `path` has no drive letter. |
| [extname](#win32extname) | Returns the file extension of `path` (including the leading dot), or `""` if there is none. |
| [format](#win32format) | Converts `path` to its Windows string representation using backslash separators. |
| [isAbsolute](#win32isabsolute) | Returns `true` if `path` is absolute (drive-rooted or UNC). |
| [join](#win32join) | Joins one or more path segments into a single `Path`. Each segment after the first must be relative. |
| [normalize](#win32normalize) | Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators. |
| [parse](#win32parse) | Parses `path` into a structured `Path` value. |
| [pathmt](#win32pathmt) |  |
| [pathmt:__tostring](#win32pathmttostring) |  |
| [relative](#win32relative) | Returns the relative path from `from` to `to`. Both paths must have the same kind and drive. |
| [resolve](#win32resolve) | Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory. |

---

## Types

### Path

```luau
type Path = win32types.Path
```

---

### PathKind

```luau
type PathKind = win32types.PathKind
```

---

### Pathlike

```luau
type Pathlike = win32types.Pathlike
```

---

## Functions and Properties

### win32.basename

Returns the last component of `path`, or `nil` if the path has no components.

```luau
(path: Pathlike) -> string?
```

---

### win32.dirname

Returns the directory portion of `path` as a string (everything except the last component).

```luau
(path: Pathlike) -> string
```

---

### win32.drive

Returns a `Path` representing just the drive root of `path` (e.g. `C:\`). Errors if `path` has no drive letter.

```luau
(path: Pathlike) -> Path
```

---

### win32.extname

Returns the file extension of `path` (including the leading dot), or `""` if there is none.

```luau
(path: Pathlike) -> string
```

---

### win32.format

Converts `path` to its Windows string representation using backslash separators.

```luau
(path: Pathlike) -> string
```

---

### win32.isAbsolute

Returns `true` if `path` is absolute (drive-rooted or UNC).

```luau
(path: Pathlike) -> boolean
```

---

### win32.join

Joins one or more path segments into a single `Path`. Each segment after the first must be relative.

```luau
(...: Pathlike) -> Path
```

---

### win32.normalize

Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.

```luau
(path: Pathlike) -> Path
```

---

### win32.parse

Parses `path` into a structured `Path` value.

```luau
(path: Pathlike) -> Path
```

---

### win32.pathmt

```luau
pathinterface.PathInterface
```

---

### win32.pathmt:__tostring

```luau
() -> string
```

---

### win32.relative

Returns the relative path from `from` to `to`. Both paths must have the same kind and drive.

```luau
(from: Pathlike, to: Pathlike) -> Path
```

---

### win32.resolve

Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.

```luau
(...: Pathlike) -> Path
```

---
