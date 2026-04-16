# fs

```luau
local fs = require("@std/fs")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [CreateDirectoryOptions](#createdirectoryoptions) | Options for `createDirectory`: |
| [DirectoryEntry](#directoryentry) | A single entry returned by `listDirectory`, containing the entry's name and type. |
| [File](#file) | An open file handle. |
| [FileMetadata](#filemetadata) | Metadata about a filesystem entry, such as size, type, and timestamps. |
| [FileType](#filetype) | The type of a filesystem entry: |
| [HandleMode](#handlemode) | How a file should be opened: |
| [RemoveDirectoryOptions](#removedirectoryoptions) | Options for `removeDirectory`: |
| [WalkOptions](#walkoptions) | Options for `walk`: |
| [WatchEvent](#watchevent) | A filesystem change event, yielded by a `Watcher`. |
| [WatchHandle](#watchhandle) | A handle to an active filesystem watcher, returned by `watch`. |
| [close](#fsclose) | Closes `file`, flushing any pending writes. |
| [copy](#fscopy) | Copies the file at `src` to `dest`. |
| [createDirectory](#fscreatedirectory) | Creates a directory at `path`. If `options.makeParents` is `true`, creates any missing parent directories as well. |
| [exists](#fsexists) | Returns `true` if a file or directory exists at `path`. |
| [link](#fslink) | Creates a hard link at `dest` pointing to `src`. |
| [listDirectory](#fslistdirectory) | Returns an array of `DirectoryEntry` values for the immediate children of the directory at `path`. |
| [metadata](#fsmetadata) | Returns metadata for the file or directory at `path`. |
| [open](#fsopen) | Opens the file at `path` in the given `mode` (defaults to `"r"`). Returns a file handle. |
| [read](#fsread) | Reads the full contents of `file` and returns them as a string. |
| [readFileToString](#fsreadfiletostring) | Returns the entire contents of the file at `filepath` as a string. |
| [remove](#fsremove) | Removes the file at `path`. |
| [removeDirectory](#fsremovedirectory) | Removes the directory at `path`. If `options.recursive` is `true`, removes all contents first. |
| [symbolicLink](#fssymboliclink) | Creates a symbolic link at `dest` pointing to `src`. |
| [type](#fstype) | Returns the `FileType` of the entry at `path` (e.g. `"file"`, `"dir"`, `"symlink"`). |
| [walk](#fswalk) | Returns an iterator over all paths under `path`. If `options.recursive` is `true`, descends into subdirectories. |
| [watch](#fswatch) | Watches `path` for filesystem changes. Returns a `Watcher` with a `next` method that returns the next |
| [write](#fswrite) | Writes `contents` to `file`. |
| [writeStringToFile](#fswritestringtofile) | Writes `contents` to the file at `filepath`, replacing any existing contents. |

---

## Types

### CreateDirectoryOptions

Options for `createDirectory`:

- `makeParents`: If `true`, creates any missing parent directories. Defaults to `false`.

```luau
type CreateDirectoryOptions = {
	makeParents: boolean?,
}
```

---

### DirectoryEntry

A single entry returned by `listDirectory`, containing the entry's name and type.

```luau
type DirectoryEntry = fs.DirectoryEntry
```

---

### File

An open file handle.

```luau
type File = fs.FileHandle
```

---

### FileMetadata

Metadata about a filesystem entry, such as size, type, and timestamps.

```luau
type FileMetadata = fs.FileMetadata
```

---

### FileType

The type of a filesystem entry:

- `"file"`: A regular file.

- `"dir"`: A directory.

- `"link"`: A symbolic link.

- `"fifo"`: A named pipe (FIFO).

- `"socket"`: A Unix domain socket.

- `"char"`: A character device.

- `"block"`: A block device.

- `"unknown"`: An entry whose type could not be determined.

```luau
type FileType = fs.FileType
```

---

### HandleMode

How a file should be opened:

- `"r"`: Open for reading. Fails if the file does not exist.

- `"w"`: Open for writing; creates the file if absent, truncates it if present.

- `"x"`: Open for exclusive creation. Fails if the file already exists.

- `"a"`: Open for appending; creates the file if absent, writes go to the end.

- `"r+"`: Open for reading and writing. Fails if the file does not exist.

- `"w+"`: Open for reading and writing; creates the file if absent, truncates it if present.

- `"x+"`: Open for reading and exclusive creation. Fails if the file already exists.

- `"a+"`: Open for reading and appending; creates the file if absent, writes go to the end.

```luau
type HandleMode = fs.HandleMode
```

---

### RemoveDirectoryOptions

Options for `removeDirectory`:

- `recursive`: If `true`, removes all contents of the directory before deleting it. Defaults to `false`.

```luau
type RemoveDirectoryOptions = {
	recursive: boolean?,
}
```

---

### WalkOptions

Options for `walk`:

- `recursive`: If `true`, descends into subdirectories. Defaults to `false`.

```luau
type WalkOptions = {
	recursive: boolean?,
}
```

---

### WatchEvent

A filesystem change event, yielded by a `Watcher`.

```luau
type WatchEvent = fs.WatchEvent
```

---

### WatchHandle

A handle to an active filesystem watcher, returned by `watch`.

```luau
type WatchHandle = fs.WatchHandle
```

---

## Functions and Properties

### fs.close

Closes `file`, flushing any pending writes.

```luau
(file: File) -> ()
```

---

### fs.copy

Copies the file at `src` to `dest`.

```luau
(src: Pathlike, dest: Pathlike) -> ()
```

---

### fs.createDirectory

Creates a directory at `path`. If `options.makeParents` is `true`, creates any missing parent directories as well.

```luau
(path: Pathlike, options: CreateDirectoryOptions?) -> ()
```

---

### fs.exists

Returns `true` if a file or directory exists at `path`.

```luau
(path: Pathlike) -> boolean
```

---

### fs.link

Creates a hard link at `dest` pointing to `src`.

```luau
(src: Pathlike, dest: Pathlike) -> ()
```

---

### fs.listDirectory

Returns an array of `DirectoryEntry` values for the immediate children of the directory at `path`.

```luau
(path: Pathlike) -> { DirectoryEntry }
```

---

### fs.metadata

Returns metadata for the file or directory at `path`.

```luau
(path: Pathlike) -> FileMetadata
```

---

### fs.open

Opens the file at `path` in the given `mode` (defaults to `"r"`). Returns a file handle.

```luau
(path: Pathlike, mode: HandleMode?) -> File
```

---

### fs.read

Reads the full contents of `file` and returns them as a string.

```luau
(file: File) -> string
```

---

### fs.readFileToString

Returns the entire contents of the file at `filepath` as a string.

```luau
(filepath: Pathlike) -> string
```

---

### fs.remove

Removes the file at `path`.

```luau
(path: Pathlike) -> ()
```

---

### fs.removeDirectory

Removes the directory at `path`. If `options.recursive` is `true`, removes all contents first.

```luau
(path: Pathlike, options: RemoveDirectoryOptions?) -> ()
```

---

### fs.symbolicLink

Creates a symbolic link at `dest` pointing to `src`.

```luau
(src: Pathlike, dest: Pathlike) -> ()
```

---

### fs.type

Returns the `FileType` of the entry at `path` (e.g. `"file"`, `"dir"`, `"symlink"`).

```luau
(path: Pathlike) -> FileType
```

---

### fs.walk

Returns an iterator over all paths under `path`. If `options.recursive` is `true`, descends into subdirectories.

See example/walk_directory.luau for usage.

```luau
(path: Pathlike, options: WalkOptions?) -> () -> Path?
```

---

### fs.watch

Watches `path` for filesystem changes. Returns a `Watcher` with a `next` method that returns the next

`WatchEvent`, or `nil` if none is available, and a `close` method to stop watching.

Note: a while loop must be used rather than a for loop. See example/watch_directory.luau for usage.

```luau
(path: Pathlike) -> Watcher
```

---

### fs.write

Writes `contents` to `file`.

```luau
(file: File, contents: string) -> ()
```

---

### fs.writeStringToFile

Writes `contents` to the file at `filepath`, replacing any existing contents.

```luau
(filepath: Pathlike, contents: string) -> ()
```

---
