# path

```luau
local path = require("@std/path")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Path](#path) | A structured, platform-aware file system path. |
| [Pathlike](#pathlike) | Anything that can be used as a path: a string, a `Path`, or raw path data. |
| [basename](#pathbasename) | Returns the last component of `path` (the filename or directory name), or `nil` if the path has no components. |
| [dirname](#pathdirname) | Returns the directory portion of `path` as a string (everything except the last component). |
| [extname](#pathextname) | Returns the file extension of `path` (including the leading dot), or `""` if there is none. |
| [format](#pathformat) | Converts `path` to its string representation using the platform's separator. |
| [isAbsolute](#pathisabsolute) | Returns `true` if `path` is absolute. |
| [join](#pathjoin) | Joins one or more path segments together into a single `Path`. Each segment after the first must be relative. |
| [normalize](#pathnormalize) | Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators. |
| [parse](#pathparse) | Parses `path` into a structured `Path` value. |
| [relative](#pathrelative) | Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative). |
| [resolve](#pathresolve) | Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory. |

---

## Types

### Path

A structured, platform-aware file system path.

```luau
type Path = pathtypes.Path
```

---

### Pathlike

Anything that can be used as a path: a string, a `Path`, or raw path data.

```luau
type Pathlike = pathtypes.Pathlike
```

---

## Functions and Properties

### path.basename

Returns the last component of `path` (the filename or directory name), or `nil` if the path has no components.

```luau
(path: Pathlike) -> string?
```

---

### path.dirname

Returns the directory portion of `path` as a string (everything except the last component).

```luau
(path: Pathlike) -> string
```

---

### path.extname

Returns the file extension of `path` (including the leading dot), or `""` if there is none.

```luau
(path: Pathlike) -> string
```

---

### path.format

Converts `path` to its string representation using the platform's separator.

```luau
(path: Pathlike) -> string
```

---

### path.isAbsolute

Returns `true` if `path` is absolute.

```luau
(path: Pathlike) -> boolean
```

---

### path.join

Joins one or more path segments together into a single `Path`. Each segment after the first must be relative.

```luau
(...: Pathlike) -> Path
```

---

### path.normalize

Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.

```luau
(path: Pathlike) -> Path
```

---

### path.parse

Parses `path` into a structured `Path` value.

```luau
(path: Pathlike) -> Path
```

---

### path.relative

Returns the relative path from `from` to `to`. Both paths must be of the same kind (both absolute or both relative).

```luau
(from: Pathlike, to: Pathlike) -> Path
```

---

### path.resolve

Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.

```luau
(...: Pathlike) -> Path
```

---
