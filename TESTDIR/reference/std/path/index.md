# path

```luau
local path = require("@std/path")
```

## path.basename

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string | nil)
```

## path.dirname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## path.extname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## path.format

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## path.isabsolute

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean)
```

## path.join

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## path.normalize

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## path.parse

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## path.posix

```luau
{ dirname: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string), extname: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string), relative: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } }), resolve: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } }), isabsolute: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (boolean), normalize: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } }), join: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } }), pathmt: { __tostring: (<recursive>) -> (string) }, basename: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string | nil), parse: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } }), format: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string) }
```

## path.relative

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## path.resolve

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## path.win32

```luau
{ dirname: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string), extname: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string), relative: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), drive: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), resolve: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), isabsolute: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean), normalize: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), join: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), pathmt: { __tostring: (<recursive>) -> (string) }, basename: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string | nil), parse: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), format: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string) }
```
