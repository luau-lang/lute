# init

## init.basename

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string | nil)
```

## init.dirname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string)
```

## init.extname

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string)
```

## init.format

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (string)
```

## init.isabsolute

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> (boolean)
```

## init.join

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } })
```

## init.normalize

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } })
```

## init.parse

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } })
```

## init.pathmt

```luau
{ __tostring: (<recursive>) -> (string) }
```

## init.relative

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }) -> ({ absolute: boolean, parts: { [number]: any } })
```

## init.resolve

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } }...) -> ({ absolute: boolean, parts: { [number]: any } })
```
