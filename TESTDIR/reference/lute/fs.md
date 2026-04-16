# fs

```luau
local fs = require("@lute/fs")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [DirectoryEntry](#directoryentry) |  |
| [FileHandle](#filehandle) |  |
| [FileMetadata](#filemetadata) |  |
| [FileType](#filetype) |  |
| [HandleMode](#handlemode) |  |
| [WatchEvent](#watchevent) |  |
| [WatchHandle](#watchhandle) |  |
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
type DirectoryEntry = {
	name: string,
	type: FileType,
}
```

---

### FileHandle

```luau
type FileHandle = {
	fd: number,
	err: number,
}
```

---

### FileMetadata

```luau
type FileMetadata = {
	type: FileType,
	permissions: { readonly: boolean },
	size: number,
	created: time.Duration,
	accessed: time.Duration,
	modified: time.Duration,
}
```

---

### FileType

```luau
type FileType = "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown"
```

---

### HandleMode

```luau
type HandleMode = "r" | "w" | "x" | "a" | "r+" | "w+" | "x+" | "a+"
```

---

### WatchEvent

```luau
type WatchEvent = {
	change: boolean,
	rename: boolean,
}
```

---

### WatchHandle

```luau
type WatchHandle = {
	close: (self: WatchHandle) -> (),
}
```

---

## Functions and Properties

### fs.close

```luau
(handle: FileHandle) -> ()
```

---

### fs.copy

```luau
(src: string, dest: string) -> ()
```

---

### fs.exists

```luau
(path: string) -> boolean
```

---

### fs.link

```luau
(src: string, dest: string) -> ()
```

---

### fs.listdir

```luau
(path: string) -> { DirectoryEntry }
```

---

### fs.mkdir

Creates a directory at the specified path.

To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.

```luau
(path: string) -> ()
```

---

### fs.open

```luau
(path: string, mode: HandleMode?) -> FileHandle
```

---

### fs.read

```luau
(handle: FileHandle) -> string
```

---

### fs.remove

```luau
(path: string) -> ()
```

---

### fs.rmdir

```luau
(path: string) -> ()
```

---

### fs.stat

```luau
(path: string) -> FileMetadata
```

---

### fs.symlink

```luau
(src: string, dest: string) -> ()
```

---

### fs.type

```luau
(path: string) -> FileType
```

---

### fs.watch

```luau
(path: string, callback: (filename: string, event: WatchEvent) -> ()) -> WatchHandle
```

---

### fs.write

```luau
(handle: FileHandle, contents: string) -> ()
```

---
