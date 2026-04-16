# trivia

```luau
local trivia = require("@std/syntax/utils/trivia")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [leftmostTrivia](#trivialeftmosttrivia) | Returns the leading trivia of the leftmost token in `n`, or an empty array if there are no tokens. |
| [rightmostTrivia](#triviarightmosttrivia) | Returns the trailing trivia of the rightmost token in `n`, or an empty array if there are no tokens. |

---

## Functions and Properties

### trivia.leftmostTrivia

Returns the leading trivia of the leftmost token in `n`, or an empty array if there are no tokens.

```luau
(n: types.AstNode) -> { types.Trivia }
```

---

### trivia.rightmostTrivia

Returns the trailing trivia of the rightmost token in `n`, or an empty array if there are no tokens.

```luau
(n: types.AstNode) -> { types.Trivia }
```

---
