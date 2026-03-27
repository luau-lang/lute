# fs

```luau
local fs = require("@lute/fs")
```

## fs.close

```lua
(handle: { err: number, fd: number }) -> ()
```

## fs.copy

```lua
(src: string, dest: string) -> ()
```

## fs.exists

```lua
(path: string) -> (boolean)
```

## fs.link

```lua
(src: string, dest: string) -> ()
```

## fs.listdir

```lua
(path: string) -> ({ [number]: any })
```

## fs.mkdir

Creates a directory at the specified path.

To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.

```lua
(path: string) -> ()
```

## fs.open

```lua
(path: string, mode: "a" | "a+" | "r" | "r+" | "w" | "w+" | "x" | "x+"?) -> ({ err: number, fd: number })
```

## fs.read

```lua
(handle: { err: number, fd: number }) -> (string)
```

## fs.remove

```lua
(path: string) -> ()
```

## fs.rmdir

```lua
(path: string) -> ()
```

## fs.stat

```lua
(path: string) -> ({ accessed: any, created: any, modified: any, permissions: { readonly: boolean }, size: number, type: "block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown" })
```

## fs.symlink

```lua
(src: string, dest: string) -> ()
```

## fs.type

```lua
(path: string) -> ("block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown")
```

## fs.watch

```lua
(path: string, callback: (filename: string, event: { change: boolean, rename: boolean }) -> ()) -> ({ close: (self: t1) -> () })
```

## fs.write

```lua
(handle: { err: number, fd: number }, contents: string) -> ()
```
