# fs

```luau
local fs = require("@lute/fs")
```

## close
```luau
(handle: FileHandle) -> ()
```

## listdir <Badge type="warning" text="yields" />
```luau
(path: string) -> { { name: string, type: string }}
```

## mkdir
```luau
(path: string, mode: number?) -> ()
```

## open
```luau
(path: string, mode: string?) -> FileHandle
```

## read
```luau
(handle: FileHandle) -> string
```

## readasync <Badge type="warning" text="yields" />
```luau
(path: string) -> string
```

## readfiletostring
```luau
(path: string) -> string
```

## remove
```luau
(path: string) -> ()
```

## rmdir
```luau
(path: string) -> ()
```

## type
```luau
(path: string) -> string
```

## write
```luau
(handle: FileHandle, data: string) -> ()
```

## writestringtofile
```luau
(path: string, data: string) -> ()
```
