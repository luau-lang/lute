# fs

```luau
local fs = require("@lute/fs")
```

## fs.close

```luau
({ fd: number, err: number }) -> ()
```

## fs.copy

```luau
(string, string) -> ()
```

## fs.exists

```luau
(string) -> (boolean)
```

## fs.link

```luau
(string, string) -> ()
```

## fs.listdir

```luau
(string) -> ({ [number]: any })
```

## fs.mkdir

Creates a directory at the specified path.

To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.

```luau
(string) -> ()
```

## fs.open

```luau
(string, "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+" | nil) -> ({ fd: number, err: number })
```

## fs.read

```luau
({ fd: number, err: number }) -> (string)
```

## fs.remove

```luau
(string) -> ()
```

## fs.rmdir

```luau
(string) -> ()
```

## fs.stat

```luau
(string) -> ({ created: any, type: "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown", accessed: any, modified: any, permissions: { readonly: boolean }, size: number })
```

## fs.symlink

```luau
(string, string) -> ()
```

## fs.type

```luau
(string) -> ("file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown")
```

## fs.watch

```luau
(string, (string, { rename: boolean, change: boolean }) -> ()) -> ({ close: (<recursive>) -> () })
```

## fs.write

```luau
({ fd: number, err: number }, string) -> ()
```
