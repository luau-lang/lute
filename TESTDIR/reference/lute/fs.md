# fs

```luau
local fs = require("@lute/fs")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [type](#fstype) |  |
| [write](#fswrite) |  |
| [close](#fsclose) |  |
| [read](#fsread) |  |
| [remove](#fsremove) |  |
| [open](#fsopen) |  |
| [listdir](#fslistdir) |  |
| [mkdir](#fsmkdir) | Creates a directory at the specified path. |
| [copy](#fscopy) |  |
| [exists](#fsexists) |  |
| [link](#fslink) |  |
| [symlink](#fssymlink) |  |
| [watch](#fswatch) |  |
| [stat](#fsstat) |  |
| [rmdir](#fsrmdir) |  |

---

## fs.type
```luau
function type(path: string) -> ("block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown")
```

---

## fs.write
```luau
function write(handle: { err: number, fd: number }, contents: string) -> ()
```

---

## fs.close
```luau
function close(handle: { err: number, fd: number }) -> ()
```

---

## fs.read
```luau
function read(handle: { err: number, fd: number }) -> (string)
```

---

## fs.remove
```luau
function remove(path: string) -> ()
```

---

## fs.open
```luau
function open(path: string, mode: "a" | "a+" | "r" | "r+" | "w" | "w+" | "x" | "x+"?) -> ({ err: number, fd: number })
```

---

## fs.listdir
```luau
function listdir(path: string) -> ({ [number]: any })
```

---

## fs.mkdir
```luau
function mkdir(path: string) -> ()
```
Creates a directory at the specified path.

To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.

---

## fs.copy
```luau
function copy(src: string, dest: string) -> ()
```

---

## fs.exists
```luau
function exists(path: string) -> (boolean)
```

---

## fs.link
```luau
function link(src: string, dest: string) -> ()
```

---

## fs.symlink
```luau
function symlink(src: string, dest: string) -> ()
```

---

## fs.watch
```luau
function watch(path: string, callback: (filename: string, event: { change: boolean, rename: boolean }) -> ()) -> ({ close: (self: t1) -> () })
```

---

## fs.stat
```luau
function stat(path: string) -> ({ accessed: any, created: any, modified: any, permissions: { readonly: boolean }, size: number, type: "block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown" })
```

---

## fs.rmdir
```luau
function rmdir(path: string) -> ()
```

---
