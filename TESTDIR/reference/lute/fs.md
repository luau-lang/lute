# fs

```luau
local fs = require("@lute/fs")
```

## fs.close

```luau
(handle: { fd: number) -> ()
```

## fs.copy

```luau
(src: string, dest: string) -> ()
```

## fs.exists

```luau
(path: string) -> (boolean)
```

## fs.link

```luau
(src: string, dest: string) -> ()
```

## fs.listdir

```luau
(path: string) -> ({ [number]: any })
```

## fs.mkdir

Creates a directory at the specified path.

To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.

```luau
(path: string) -> ()
```

## fs.open

```luau
(path: string, mode: "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+" | nil) -> ({ fd: number, err: number })
```

## fs.read

```luau
(handle: { fd: number) -> (string)
```

## fs.remove

```luau
(path: string) -> ()
```

## fs.rmdir

```luau
(path: string) -> ()
```

## fs.stat

```luau
(path: string) -> ({ created: any, type: "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown", accessed: any, modified: any, permissions: { readonly: boolean }, size: number })
```

## fs.symlink

```luau
(src: string, dest: string) -> ()
```

## fs.type

```luau
(path: string) -> ("file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown")
```

## fs.watch

```luau
(path: string, callback: (filename: string) -> ({ close: (self: <recursive>) -> () })
```

## fs.write

```luau
(handle: { fd: number, contents: err: number }) -> ()
```
