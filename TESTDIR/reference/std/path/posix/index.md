# posix

```luau
local posix = require("@std/path/posix")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Path](#path) |  |
| [Pathlike](#pathlike) |  |
| [basename](#posixbasename) | Returns the last component of `path`, or `nil` if the path has no components. |
| [dirname](#posixdirname) | Returns the directory portion of `path` as a string (everything except the last component). |
| [extname](#posixextname) | Returns the file extension of `path` (including the leading dot), or `""` if there is none. |
| [format](#posixformat) | Converts `path` to its POSIX string representation. |
| [isAbsolute](#posixisabsolute) | Returns `true` if `path` is absolute (begins with `/`). |
| [join](#posixjoin) | Joins one or more path segments into a single `Path`. Each segment after the first must be relative. |
| [normalize](#posixnormalize) | Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators. |
| [parse](#posixparse) | Parses `path` into a structured `Path` value. |
| [pathmt](#posixpathmt) |  |
| [pathmt:__tostring](#posixpathmttostring) |  |
| [relative](#posixrelative) | Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative). |
| [resolve](#posixresolve) | Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory. |

---

## Types

### Path

```luau
type Path = posixtypes.Path
```

---

### Pathlike

```luau
type Pathlike = posixtypes.Pathlike
```

---

## Functions and Properties

### posix.basename

Returns the last component of `path`, or `nil` if the path has no components.

```luau
(path: Pathlike) -> string?
```

---

### posix.dirname

Returns the directory portion of `path` as a string (everything except the last component).

```luau
(path: Pathlike) -> string
```

---

### posix.extname

Returns the file extension of `path` (including the leading dot), or `""` if there is none.

```luau
(path: Pathlike) -> string
```

---

### posix.format

Converts `path` to its POSIX string representation.

```luau
(path: Pathlike) -> string
```

---

### posix.isAbsolute

Returns `true` if `path` is absolute (begins with `/`).

```luau
(path: Pathlike) -> boolean
```

---

### posix.join

Joins one or more path segments into a single `Path`. Each segment after the first must be relative.

```luau
(...: Pathlike) -> Path
```

---

### posix.normalize

Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.

```luau
(path: Pathlike) -> Path
```

---

### posix.parse

Parses `path` into a structured `Path` value.

```luau
(path: Pathlike) -> Path
```

---

### posix.pathmt

```luau
pathinterface.PathInterface
```

---

### posix.pathmt:__tostring

```luau
() -> string
```

---

### posix.relative

Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative).

```luau
(from: Pathlike, to: Pathlike) -> Path
```

---

### posix.resolve

Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.

```luau
(...: Pathlike) -> Path
```

---
