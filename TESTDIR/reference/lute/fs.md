# fs

```luau
local fs = require("@lute/fs")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [close](#fsclose) |  |
| [copy](#fscopy) |  |
| [exists](#fsexists) |  |
| [link](#fslink) |  |
| [listdir](#fslistdir) |  |
| [mkdir](#fsmkdir) | Creates a directory at the specified path. |
| [open](#fsopen) |  |
| [read](#fsread) |  |
| [remove](#fsremove) |  |
| [rmdir](#fsrmdir) |  |
| [stat](#fsstat) |  |
| [symlink](#fssymlink) |  |
| [type](#fstype) |  |
| [watch](#fswatch) |  |
| [write](#fswrite) |  |

---

## Types

### DirectoryEntry
```luau
type DirectoryEntry = { name: string, type: "block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown" }
```

### FileHandle
```luau
type FileHandle = { err: number, fd: number }
```

### FileMetadata
```luau
type FileMetadata = { accessed: {}, created: {}, modified: {}, permissions: { readonly: boolean }, size: number, type: "block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown" }
```

### FileType
```luau
type FileType = "block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown"
```

### HandleMode
```luau
type HandleMode = "a" | "a+" | "r" | "r+" | "w" | "w+" | "x" | "x+"
```

### WatchEvent
```luau
type WatchEvent = { change: boolean, rename: boolean }
```

### WatchHandle
```luau
type WatchHandle = { close: (self: t1) -> () }
```

## Properties and Functions

## fs.close
```luau
function close(handle: { err: number, fd: number }) -> ()
```
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

## fs.open
```luau
function open(path: string, mode: "a" | "a+" | "r" | "r+" | "w" | "w+" | "x" | "x+"?) -> ({ err: number, fd: number })
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

## fs.rmdir
```luau
function rmdir(path: string) -> ()
```
---

## fs.stat
```luau
function stat(path: string) -> ({ accessed: {}, created: {}, modified: {}, permissions: { readonly: boolean }, size: number, type: "block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown" })
```
---

## fs.symlink
```luau
function symlink(src: string, dest: string) -> ()
```
---

## fs.type
```luau
function type(path: string) -> ("block" | "char" | "dir" | "fifo" | "file" | "link" | "socket" | "unknown")
```
---

## fs.watch
```luau
function watch(path: string, callback: (filename: string, event: { change: boolean, rename: boolean }) -> ()) -> ({ close: (self: t1) -> () })
```
---

## fs.write
```luau
function write(handle: { err: number, fd: number }, contents: string) -> ()
```
---
