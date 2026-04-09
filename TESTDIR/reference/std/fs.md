# fs

```luau
local fs = require("@std/fs")
```

## fs.close

```luau
(file: File) -> ()
```

## fs.copy

```luau
(src: Pathlike, dest: Pathlike) -> ()
```

## fs.createDirectory

```luau
(path: Pathlike, options: CreateDirectoryOptions?) -> ()
```

## fs.exists

```luau
(path: Pathlike) -> boolean
```

## fs.link

```luau
(src: Pathlike, dest: Pathlike) -> ()
```

## fs.listDirectory

```luau
(path: Pathlike) -> { DirectoryEntry }
```

## fs.metadata

```luau
(path: Pathlike) -> FileMetadata
```

## fs.open

```luau
(path: Pathlike, mode: HandleMode?) -> File
```

## fs.read

```luau
(file: File) -> string
```

## fs.readFileToString

```luau
(filepath: Pathlike) -> string
```

## fs.remove

```luau
(path: Pathlike) -> ()
```

## fs.removeDirectory

```luau
(path: Pathlike, options: RemoveDirectoryOptions?) -> ()
```

## fs.symbolicLink

```luau
(src: Pathlike, dest: Pathlike) -> ()
```

## fs.type

```luau
(path: Pathlike) -> FileType
```

## fs.walk

Note: for loops do not support yielding generalized iterators, so we cannot use fs.walk as `for path in fs.walk(...) do` directly. A while loop can be used instead. See example/walk_directory.luau for usage.

```luau
(path: Pathlike, options: WalkOptions?) -> () -> Path?
```

## fs.watch

Iterator function that yields filename and event pairs when changes occur in the watched path.

Also provides a `close` method to stop watching.

Note: for loops do not support yielding generalized iterators, so we cannot use fs.watch as `for _ in fs.watch(...) do` directly. A while loop can be used instead. See example/watch_directory.luau for usage.

```luau
(path: Pathlike) -> Watcher
```

## fs.write

```luau
(file: File, contents: string) -> ()
```

## fs.writeStringToFile

```luau
(filepath: Pathlike, contents: string) -> ()
```
