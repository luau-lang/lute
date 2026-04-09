# fs

```luau
local fs = require("@lute/fs")
```

## fs.close

```luau
(handle: FileHandle) -> ()
```

## fs.copy

```luau
(src: string, dest: string) -> ()
```

## fs.exists

```luau
(path: string) -> boolean
```

## fs.link

```luau
(src: string, dest: string) -> ()
```

## fs.listdir

```luau
(path: string) -> { DirectoryEntry }
```

## fs.mkdir

Creates a directory at the specified path.

To set the permissions mode for a directory (Unix only), see @std/process for `run` or `system` to shell out to `chmod` or the equivalent.

```luau
(path: string) -> ()
```

## fs.open

```luau
(path: string, mode: HandleMode?) -> FileHandle
```

## fs.read

```luau
(handle: FileHandle) -> string
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
(path: string) -> FileMetadata
```

## fs.symlink

```luau
(src: string, dest: string) -> ()
```

## fs.type

```luau
(path: string) -> FileType
```

## fs.watch

```luau
(path: string, callback: (filename: string, event: WatchEvent) -> ()) -> WatchHandle
```

## fs.write

```luau
(handle: FileHandle, contents: string) -> ()
```
