# init

## init.basename

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string | nil)
```

## init.dirname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## init.extname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## init.format

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## init.isabsolute

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean)
```

## init.join

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.normalize

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.parse

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.posix

```luau
{ dirname: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string), extname: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string), relative: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } }), resolve: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } }), isabsolute: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (boolean), normalize: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } }), join: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } }), pathmt: { __tostring: (<recursive>) -> (string) }, basename: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string | nil), parse: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } }), format: (string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string) }
```

## init.relative

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.resolve

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.win32

```luau
{ dirname: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string), extname: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string), relative: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), drive: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), resolve: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), isabsolute: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean), normalize: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), join: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), pathmt: { __tostring: (<recursive>) -> (string) }, basename: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string | nil), parse: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }), format: (string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string) }
```
