# stringext

```luau
local stringext = require("@std/stringext")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [count](#stringextcount) | Counts the number of occurrences of `pattern` in `str`, optionally restricted to the range `[startPos, endPos]`. |
| [hasPrefix](#stringexthasprefix) | Returns `true` if `str` begins with `prefix`. |
| [hasSuffix](#stringexthassuffix) | Returns `true` if `str` ends with `suffix`. |
| [removePrefix](#stringextremoveprefix) | Returns `str` with `prefix` removed from the front. If `str` does not start with `prefix`, returns `str` unchanged. |
| [removeSuffix](#stringextremovesuffix) | Returns `str` with `suffix` removed from the end. If `str` does not end with `suffix`, returns `str` unchanged. |
| [trim](#stringexttrim) | Returns `str` with leading and trailing whitespace removed. |

---

## Functions and Properties

### stringext.count

Counts the number of occurrences of `pattern` in `str`, optionally restricted to the range `[startPos, endPos]`.

```luau
(str: string, pattern: string, startPos: number?, endPos: number?) -> number
```

---

### stringext.hasPrefix

Returns `true` if `str` begins with `prefix`.

```luau
(str: string, prefix: string) -> boolean
```

---

### stringext.hasSuffix

Returns `true` if `str` ends with `suffix`.

```luau
(str: string, suffix: string) -> boolean
```

---

### stringext.removePrefix

Returns `str` with `prefix` removed from the front. If `str` does not start with `prefix`, returns `str` unchanged.

```luau
(str: string, prefix: string) -> string
```

---

### stringext.removeSuffix

Returns `str` with `suffix` removed from the end. If `str` does not end with `suffix`, returns `str` unchanged.

```luau
(str: string, suffix: string) -> string
```

---

### stringext.trim

Returns `str` with leading and trailing whitespace removed.

```luau
(str: string) -> string
```

---
