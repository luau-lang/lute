# fs

```luau
local fs = require("@std/fs")
```

## fs.close

```luau
({ fd: number, err: number }) -> ()
```

## fs.copy

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ()
```

## fs.createdirectory

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, { makeparents: boolean | nil } | nil) -> ()
```

## fs.exists

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean)
```

## fs.link

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ()
```

## fs.listdirectory

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ [number]: any })
```

## fs.metadata

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ created: any, type: "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown", accessed: any, modified: any, permissions: { readonly: boolean }, size: number })
```

## fs.open

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+" | nil) -> ({ fd: number, err: number })
```

## fs.read

```luau
({ fd: number, err: number }) -> (string)
```

## fs.readfiletostring

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## fs.remove

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ()
```

## fs.removedirectory

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, { recursive: boolean | nil } | nil) -> ()
```

## fs.symboliclink

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ()
```

## fs.type

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ("file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown")
```

## fs.walk

Note: for loops do not support yielding generalized iterators, so we cannot use fs.walk as `for path in fs.walk(...) do` directly. A while loop can be used instead. See example/walk_directory.luau for usage.

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, { recursive: boolean | nil } | nil) -> (() -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | nil))
```

## fs.watch

Iterator function that yields filename and event pairs when changes occur in the watched path.

Also provides a `close` method to stop watching.

Note: for loops do not support yielding generalized iterators, so we cannot use fs.watch as `for _ in fs.watch(...) do` directly. A while loop can be used instead. See example/watch_directory.luau for usage.

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ next: (<recursive>) -> ({ rename: boolean, change: boolean } | nil), close: (<recursive>) -> () })
```

## fs.write

```luau
({ fd: number, err: number }, string) -> ()
```

## fs.writestringtofile

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string) -> ()
```
