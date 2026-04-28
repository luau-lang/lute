<!-- markdownlint-disable MD024 -->
# Lute FFI Specification (Proposed)

## Goals

- C-like and explicit API.
- Practical and concise for common usage.
- Preserve low-level power, including unsafe-capable paths.
- Keep `ffi` generic and `ffi.c` C-specific.
- Keep ownership and aliasing rules predictable.

## Non-goals

- Parsing C headers in this phase.
- Preventing all undefined behavior.
- Guaranteeing full memory safety for arbitrary FFI operations.

---

## Design Motivation

### The Core Problem

When a C function is called with arguments via implicit marshaling, the runtime converts Luau values into C-compatible form and stores them in an internal argument vector. This vector is reused across successive calls. If a foreign function retains a pointer to the vector's contents and later that vector is reused for a different call, the old pointer now addresses different data, causing silent corruption.

### Comparison to LuaJIT FFI

This design is similar to LuaJIT in some respects: both offer explicit allocation via `c.new(...)` (proposed here) or `ffi.new(...)` (LuaJIT), and both allow passing Luau values to C functions. However, they diverge significantly in lifetime and dependency tracking:

- **LuaJIT**: relies on GC + manual anchoring. If you allocate a buffer and get a pointer to it, and pass it to a C function which ends up retaining it, and you lose the Lua reference, the memory may be collected. You must manually keep references alive.
- **This design**: makes dependency relationships explicit in the runtime ownership and dependency tracking model. When you derive pointers, references, or field views from an owner, the runtime tracks the dependency. The owner cannot be finalized while dependents are alive.

### Concrete Example: Dangling Pointers

**LuaJIT gotcha:**

```luau
local p = ffi.cast("int*", ffi.new("int[1]"))
```

This looks safe, but is not:

- `ffi.new("int[1]")` returns a cdata that immediately loses its Lua reference.
- `p` is just a raw pointer. LuaJIT does not track that it depends on the array.
- GC can collect the array → `p` becomes a dangling pointer.
- To avoid this, you must manually anchor the array:

```luau
local arr = ffi.new("int[1]")
local p = ffi.cast("int*", arr)
```

Here:

- `arr` owns the array and keeps it alive.
- If `arr` is collected, `p` becomes dangling. You must keep `arr` alive as long as you need `p`.
- This means if `p` needs to outlive the scope where `arr` is defined, you must manually manage that lifetime, which can be error-prone, and awkward to work with in practice.

**This design:**

```luau
-- creating the types separately for readability
local arr_t = c.array(c.int, 1)
local ptr_t = c.ptr(c.int)

local ptr = c.cast(c.new(arr_t), ptr_t) -- cast the array to a pointer
```

Here:

- `c.new(arr_t)` allocates an integer array and owns it.
- `c.cast(arr, c.ptr(c.int))` produces a pointer value that keeps the array allocation alive.
- `ptr:deref()` produces a view of the first element. The array stays alive as long as `elem` exists, even if `arr` itself is dropped.
- **No manual anchoring needed.**

### Tradeoffs for Users

**Advantages:**

- Pointer lifetimes are explicit and predictable, with no manual anchoring tricks needed.
- Users can choose to pass plain Luau values for callthrough, or use `CData` when pointer persistence is needed.
- Specialized `CData` types (`CPointerData`, `CArrayData`, `CStructData`) are indexable and readable just like real C arrays/pointers/structs. You can call `:read()`, `:write()`, index with `[]`, and dereference pointers. All the familiar C operations are available on the wrapped types.
- Clear ownership: you own the `CData`, you control when it dies. Dependencies keep the owner alive.
- Hybrid lifetime control: automatic GC-based retention for typical cases, with explicit `retain()` and `release()` APIs available for scenarios requiring precise manual lifetime management.
- Compatible with C's semantic model of addresses and memory.

**Disadvantages:**

- Handling complex lifetimes can be tedious and non-trivial.
- Requires the user to reason explicitly about how long data must remain valid, especially when passing pointers across foreign function boundaries.
- Slightly more verbose than fully implicit marshaling for simple cases, though direct Luau values remain available for callthrough.

This design prioritizes correctness and explicitness over maximum convenience, accepting that users who work with C must think about ownership and lifetimes anyway.

---

## Module Split

`ffi` handles loader/runtime concerns:

- `ffi.open`
- `ffi.process` (global process symbol-space handle)
- architecture properties (`arch`, `pointer_size`)
- opaque `LibraryHandle`

`ffi.c` handles C concerns:

- C type system (`CType`)
- C data system (`CData`)
- symbol binding and calls
- ownership and aliasing semantics

---

## Library Handles

### Overview

A `LibraryHandle` is an opaque reference to a loaded dynamic library or the process symbol space. It is the gateway for all symbol resolution. Handles are obtained through `ffi.open` or via the pre-existing `ffi.process` handle.

`ffi.process` is a special handle representing the global symbol namespace of the running process. It is always available without any `open` call and cannot be closed.

### API

```luau
export type FFI = {
    arch: string,
    pointer_size: number,
    open: (nameOrPath: string, opts: OpenOptions?) -> LibraryHandle,
    process: LibraryHandle,
    c: CNamespace,
}

export type OpenOptions = {
    global: boolean?,
    now: boolean?,
}

export type LibraryHandle = {
    close: (self: LibraryHandle) -> (),
    is_open: (self: LibraryHandle) -> boolean,

    path: string,
    kind: "dynamic" | "process",
}
```

A `LibraryHandle` with `kind = "process"` is `ffi.process`. It is not closeable. A `LibraryHandle` with `kind = "dynamic"` wraps a loaded shared library and can be closed via `:close()`.

### GC and Finalization

Library handles are kept alive as long as any `CData` values loaded from them are still alive. A handle's underlying library will not be unloaded until all of its symbol dependents have been finalized. Calling `:close()` while dependents exist is a no-op or deferred, depending on platform behavior.

---

## CType

### Overview

`CType` describes the shape, size, and alignment of a C value. Types are pure descriptors that hold no memory and carry no runtime allocation. They may reference other `CType` instances (e.g. a pointer type references its pointee, a struct type references its field types), and for that reason they participate in ref counting and support `retain`/`release` to prevent the destruction of a type that is still referenced by another.

Every `CData` instance is associated with a `CType` that describes what it holds. `CType` and `CData` are otherwise independent: a `CType` does not know about any `CData` instances that use it.

### Primitives and Void

Primitive types and `void` are pre-constructed singletons exposed directly on the `c` namespace. They do not need to be constructed. They simply exist.

```luau
export type CType = {
    kind: string,
    size: number,
    align: number,
    name: string?,
}

export type CVoidType = CType & {
    kind: "void",
}

export type CPrimitiveType = CType & {
    kind: "primitive",
    primitive: CPrimitiveId,
}

export type CPrimitiveId =
    "bool" | "char" | "schar" | "uchar" |
    "short" | "ushort" | "int" | "uint" |
    "long" | "ulong" |
    "float" | "double" |
    "int8_t" | "uint8_t" | "int16_t" | "uint16_t" |
    "int32_t" | "uint32_t" | "int64_t" | "uint64_t" |
    "size_t" | "ssize_t" | "intptr_t" | "uintptr_t"
```

Available primitive singletons on `c`:

```cpp
bool, 
char, schar, uchar,
short, ushort,
int, uint,
long, ulong,
float, double,
int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t,
size_t, ssize_t, intptr_t, uintptr_t
```

- `c.void` is the void type, which is not a primitive and cannot be instantiated. It is used for pointer construction and function return types.
- `c.char` is the `char` type. It is distinct from `c.schar` and `c.uchar` and has its own signedness determined by the platform ABI.

### Compound Types

Compound types are constructed via calls on the `c` namespace. Because they reference other `CType` instances, the referenced types are retained for the lifetime of the compound type.

```luau
export type CPointerType = CType & {
    kind: "pointer",
    pointee: CType,
}

export type CArrayType = CType & {
    kind: "array",
    elementType: CType,
    length: number,
}

export type CStructType = CType & {
    kind: "struct",
    fields: { CStructFieldLayout },
}

export type CStructFieldLayout = {
    name: string,
    type: CType,
    offset: number,
    align: number,
}

export type CFunctionType = CType & {
    kind: "function",
    params: { CType },
    result: CType,
    abi: string,
    symbol: string?,
    vararg: boolean,

    set_symbol: (self: CFunctionType, symbol: string) -> CFunctionType,
    set_abi: (self: CFunctionType, abi: CAbiEnum) -> CFunctionType,
}
```

Construction functions:

```luau
c.ptr(t: CType) -> CPointerType
c.array(elemType: CType, len: number) -> CArrayType
c.struct(fields: { StructFieldDef }, opts: StructTypeOptions?) -> CStructType
c.func(result: CType) -> (...CType) -> CFunctionType
```

`c.voidptr` is a pre-constructed convenience alias for `c.ptr(c.void)`.

#### Struct Options

```luau
export type StructTypeOptions = {
    name: string?,
    packed: boolean?,
    align: number?,
}

export type StructFieldDef = { [string]: CType }
```

#### Function Type Construction

Function types use a curried call:

```luau
local add_t = c.func(c.int)(c.int, c.int)
    :set_symbol("add")
    :set_abi(c.abi.default)
```

`set_symbol` annotates the type with a symbol name for use during bulk loading. `set_abi` sets the calling convention, defaulting to the platform default. Both return `self` for chaining.

Vararg functions are not yet formally specified.

---

## CData

### Overview

`CData` is the runtime representation of a C value. Every `CData` has a corresponding `CType` that describes what it contains. A `CData` is either an **owner** or a **view**:

- **Owners** hold backing memory. They free it on finalization (if `owns_memory` applies).
- **Views** refer to existing memory. Views can be **dependent** (carry a reference edge to a root owner) or **non-dependent** (no edge).

Non-dependent views do not keep anything alive and typically come from raw pointers or casts that are not tied to a known allocation. When a view has a dependency edge, chains are transitive and flattened: a view of a view retains the original owner, not the intermediate. Intermediate views can be collected freely once no Lua variable holds them. Non-dependent views do not participate in dependency tracking.

### Base Types

`CData` `size`, `align`, and `kind` always match the associated `CType`. `CData` is the base for all runtime C values, and `CWritableData` marks values whose backing storage can be overwritten with `write()`.

```luau
export type CData = {
    type: CType,
    size: number,
    align: number,
    kind: string,

    retain: (self: CData) -> (),
    release: (self: CData) -> (),

    isnull: (self: CData) -> boolean,
}

export type CWritableData = CData & {
    write: (self: CWritableData, value: any) -> (),
}
```

### Primitive Data

`CPrimitiveData` represents a C scalar value (for example `int` or `double`) stored in backing memory. Use `read()` to get a Luau value, `write()` to set it, and `asbuffer()` to access raw bytes.

```luau
export type CPrimitiveData = CWritableData & {
    read: (self: CPrimitiveData) -> number | integer,
    asbuffer: (self: CPrimitiveData) -> buffer,
}
```

`read()` returns a Luau `number` for all types smaller than 8 bytes, including floats. For 8-byte integer types (`int64`, `uint64`, and any `long` that is 8 bytes on the target platform), it returns a Luau `integer` to avoid silent precision loss (since `number` is a 64-bit double and can only represent integers exactly up to 2^53).

### Pointer Data

`CPointerData` represents a C pointer value (`T*`) stored in backing memory. `read()` returns the address, `deref()` or indexing yields a view of the pointee, and `offset()` performs pointer arithmetic. If the pointer has a dependency edge, derived views inherit it; otherwise they are non-dependent.

Bounds metadata is only present when derived from a `CArrayData` via arithmetic or when manually set via `set_bound`. `bound` is the total element count of the original array, and `offset_index` is how many elements past the base this pointer currently sits. The base address can be recovered as `read() - (offset_index * elementSize)`.

`set_bound` sets an explicit element bound on an otherwise raw `CPointerData`. When a bound is first set, `offset_index` is initialized to 0. Passing `nil` removes the bound and disables checking; dependency edges are unchanged.

```luau
export type CPointerData = CWritableData & {
    read: (self: CPointerData) -> integer,
    asbuffer: (self: CPointerData) -> buffer,

    deref: (self: CPointerData, index: number?) -> CData,
    offset: (self: CPointerData, elements: number) -> CPointerData,

    bound: number?,
    offset_index: number?,

    set_bound: (self: CPointerData, bound: number?) -> (),
}
```

The backing storage of a `CPointerData` holds the true address of its pointee. `read()` reads that value like any other `CData`. Arithmetic on a `CPointerData` accumulates into `offset_index` but does not change what is stored. `offset_index` is metadata only. Accessing outside `[0, bound)` is a runtime error when a bound is set; if no bound is set, arithmetic is entirely unchecked.

### Array Data

`CArrayData` represents a C array (`T[n]`) and acts as a bounded pointer to its first element. Indexing produces element views that inherit any dependency edge from the array value, otherwise they are non-dependent. It supports `asarray()`, pointer arithmetic, and passing where a pointer is expected.

```luau
export type CArrayData = CPointerData & {
    owns_memory: boolean,
    asarray: (self: CArrayData, recursive: boolean?) -> { CData | any },
}
```

`CArrayData` is a subtype of `CPointerData` whose backing storage always holds the true base address of the array, never an offset. It has no offset of its own, only a `bound` representing the total element count. Performing arithmetic on a `CArrayData` produces a `CPointerData` whose backing storage holds the address of the element at that offset, with `offset_index` and `bound` set. The `offset_index` accumulates across further arithmetic, always measured from the original base. The base address can be recovered as `read() - (offset_index * elementSize)`.

`owns_memory` is true for allocations via `c.new` or `c.string`, and false when the `CArrayData` was acquired through `c.cast`.

A `CArrayData` allocation consists of an element buffer plus a pointer-sized backing storage that holds the base address of that buffer. The backing storage is what `read()` returns and what is copied into call argument vectors when an array decays to a pointer.

### Struct Data

`CStructData` represents a C struct value. Field access via `s.field` produces a view; if the struct has a dependency edge the field view inherits it, otherwise it is non-dependent. Use `asarray()` or `asdict()` to read fields, and `write()` to assign a whole-struct value.

```luau
export type CStructData = CWritableData & {
    asarray: (self: CStructData, recursive: boolean?) -> { CData | any },
    asdict: (self: CStructData, recursive: boolean?) -> { [string]: CData | any },
}
```

### Function Data

`CFunctionData` represents a C function pointer or callback. It can be called directly via `__call`, and `get_closure()` returns a Luau callable that forwards to the same function.

```luau
export type CFunctionData = CData & {
    __call: (self: CFunctionData, ...any) -> any,
    get_closure: (self: CFunctionData) -> (...any) -> any,
}
```

`CFunctionData` is callable directly. See the [Calling](#calling) section for argument marshaling rules.

### Allocation

All heap allocations go through `c.new`:

```luau
c.new: (t: CType, init: any?) -> CData
```

- `c.new(t)` allocates and owns a value of type `t`, zero-initialized unless `init` is provided.
- `c.new(c.array(elem, n))` allocates and owns an array, returning a `CArrayData` with `owns_memory = true` and `bound = n`.
- `c.new(fnType, luaFunction)` allocates a C-callable callback trampoline, returning a `CFunctionData`.
- `c.string(s, signed?)` is a convenience wrapper that allocates and owns a null-terminated `char` array, returned as `CArrayData` with `owns_memory = true`.

`c.new(c.void, ...)` is always a runtime error. Void instances cannot be created.

### Conversions

```luau
c.cast: (value: CData, to: CType) -> CData
```

`c.cast` produces a new standalone `CData` value and allocates result storage. It does not share backing storage with the source. For pointer and array results, if the source carries a dependency edge to a root allocation, the result keeps that dependency edge; if the source has no dependency edge, the result is non-dependent. If the source allocation must outlive the result, you are responsible for keeping it alive, either by retaining a Lua reference or via `retain()`.

`c.cast` supports:

- Numeric conversions between primitive integer and float types.
- Pointer-to-pointer conversions, including unrelated pointer types.
- Integer and pointer conversions using the target pointer width.
- Array and pointer conversions (arrays decay to pointers; pointers can be cast to arrays).

Array and pointer casting rules:

- Casting a `CArrayData` to a pointer type yields a `CPointerData` whose value is the base address of the array. If the source had bounds metadata, it is preserved. If the source had a dependency edge, it is preserved.
- Casting a `CPointerData` to a `CArrayType` yields a `CArrayData` whose base address is the current pointer value. If the source has `bound` and `offset_index` metadata, the cast is valid only when `bound - offset_index` is at least the target array length; otherwise it is a runtime error. When no bounds metadata is present, the cast proceeds unchecked, but the resulting array still uses the target array length as its bound.

A `CArrayData` acquired through `c.cast` has `owns_memory = false` and does not free the pointed-to memory on finalization. If the source had a dependency edge, it is preserved.

`c.ptr(v: CData)` takes the address of the `CData`'s backing storage and returns a bounded `CPointerData`. The bound is inherited from the source if it is a `CArrayData`, otherwise it is set to 1. The dependency edge is resolved without extending the chain: if the source owns its memory, the result depends on the source directly; if the source is itself a dependent view, the result inherits that existing edge; if the source has no dependency, the result has none.

### Initialization and Write Values

The `init` argument to `c.new` and the `value` argument to `:write()` follow the same rules per type.

When a `buffer` is provided, it must be at least the type size in bytes; extra bytes are ignored. `c.new` always allocates the target storage and copies from the buffer into that storage. Buffers are interpreted as little-endian; no byte swapping is performed.

**Primitives:** `nil` zero-initializes. `buffer` is always accepted (subject to the size rule above) and interpreted as raw bytes. `number` is always accepted. `integer` is accepted for integer primitives.

**Structs:** `nil` zero-initializes. `buffer` is always accepted (subject to the size rule above). A Luau array maps values positionally to fields in declaration order. A Luau dictionary maps values by field name. Partial initialization leaves unspecified fields zero-initialized. Values for each field follow the same rules recursively for that field's type.

**Arrays:** `nil` zero-initializes. `buffer` is always accepted (subject to the size rule above). A Luau array maps values positionally. A single non-table value is accepted only if the array length is 1. Values for each element follow the same rules recursively for the element type.

**Functions:** A Lua function is required as the init argument to `c.new`. `nil` or any other value is a runtime error. `:write()` is not available on `CFunctionData`.

### asarray, asdict, and the recursive flag

`CArrayData:asarray(recursive?)` converts the array to a Luau array of values. With `recursive = false` (the default), each element is returned as a `CData` value. With `recursive = true`, all nested values are recursively converted: nested arrays become Luau arrays, nested structs become Luau dictionaries keyed by field name, and primitives become Luau values.

`CStructData:asarray(recursive?)` converts the struct fields to a Luau array in declaration order. `CStructData:asdict(recursive?)` converts the struct fields to a Luau dictionary keyed by field name. The `recursive` flag behaves the same way.

When encountering a nested struct during any recursive conversion, it is always converted as a dictionary regardless of whether `asarray` or `asdict` was called on the outer value. Structs are field-indexed by nature; converting them as positional arrays would discard field name information.

### Ownership and Lifetime

Every `CData` is either an owner, a dependent view, or a non-dependent view. Dependency chains are transitive and flattened to one hop. No matter how many arithmetic steps or view derivations are taken, the chain never grows beyond a single edge to the original root allocation.

**Non-owning views are produced by:**

- Array element access (`arr[i]`)
- Struct field access (`s.field`)
- Pointer dereference and indexing (`p:deref()`, `p[i]`)
- `c.ptr(v)` when given a `CData` value

If the source carries a dependency edge (owner or dependent view), the view inherits it; if the source has no dependency edge, the view is non-dependent.

Pointer arithmetic follows the same rule: the resulting `CPointerData` inherits the dependency edge of the source pointer, never depending on the pointer itself. If the source has no dependency edge, the result is non-dependent.

**Manual lifetime controls:**

For cases where automatic lifetime tracking is not sufficient, such as when you intentionally drop your Lua reference to an allocation while still needing the memory to remain alive, you can pin it manually:

- `value:retain()` prevents reclamation regardless of remaining Lua references.
- `value:release()` undoes one `retain()` call and errors on underflow.

Manual retain/release is root-scoped: you can call `retain` on one alias and `release` on another alias to the same allocation and it will work correctly.

**GC and finalization:**

- Userdata finalizers remove handle refs and dependency edges.
- Root finalizer runs once at terminal state.
- Managed roots free backing memory.
- Library roots close only when symbol dependents are gone.
- In normal operation, `refcount > 0` implies `luaref != LUA_NOREF`, so the userdata is not collectible. During `lua_State` shutdown, this invariant does not matter.

### Equality

If `CData` implements equality, two values are equal when their backing storage addresses are equal. Type is not considered; different typed views of the same address compare equal. This is identity, not data equality. To compare pointer values, compare `:read()` on `CPointerData`.

---

## Symbol Loading

### Overview

`c.load` resolves symbols from a `LibraryHandle` and wraps them as `CData`. The provided `CType` determines how the symbol's address is interpreted and what kind of `CData` is returned. This works for any exported symbol, including functions, global variables, constants, and other data symbols.

### API

```luau
c.load:
    (lib: LibraryHandle, symbol: string, sig: CType, opts: LoadOneOptions?) -> CData
  & (lib: LibraryHandle, spec: { [string]: CType }, opts: LoadManyOptions?) -> { [string]: CData? }

export type LoadOneOptions = {
    strict: boolean?, -- default true
}

export type LoadManyOptions = {
    strict: boolean?, -- default true
}
```

`c.load` has two forms.

**Single load:** the symbol name is passed directly as a string. The `:set_symbol(...)` annotation on the type is not used in this form.

```luau
local strlen_t = c.func(c.size_t)(c.ptr(c.char))
local strlen = c.load(libc, "strlen", strlen_t)

local errno = c.load(libc, "errno", c.int) -- loading a global variable
```

**Bulk load:** a table of `CType` values is passed. The symbol looked up for each entry is taken from the `:set_symbol(...)` annotation on the type if one was set, otherwise the table field name is used as a fallback.

```luau
local lib = c.load(libc, {
    puts   = c.func(c.int)(c.ptr(c.char)),
    memcpy = c.func(c.ptr(c.void))(c.ptr(c.void), c.ptr(c.void), c.size_t),
    errno  = c.int,
})
```

With `strict = true` (the default), any symbol that cannot be resolved raises an error immediately. With `strict = false`, missing symbols produce `nil` entries in the result table rather than erroring.

### Calling

A `CFunctionData` is callable directly. Arguments are marshaled positionally against the parameter types declared in the `CFunctionType`.

**Luau values** passed where a primitive or pointer type is expected are marshaled by value into the call. The marshaled data lives only for the duration of the call and no pointer to it remains valid afterward. This is fine for callthrough, but you must not pass a Luau value where the callee will retain a pointer to it across calls.

**`CData` values** passed as arguments are used directly. The caller is responsible for ensuring the backing allocation outlives the call and any subsequent use by the callee.

**Structs by value** are copied into the call argument vector when the parameter type is a struct.

**Arrays** are never passed by value. Array parameter types decay to pointers to the element type; a `CArrayData` supplies its base pointer, and argument marshaling follows the pointer rules.

**Argument count** must match the declared parameter count exactly for non-vararg functions. Excess or missing arguments raise an error at call time.

**Return values** are wrapped in the `CData` type corresponding to the declared return type. A `void` return produces no value. Pointer returns produce a raw `CPointerData` with no bounds metadata and no ownership. Arithmetic on a raw `CPointerData` is completely unchecked. If you know the bounds of what was returned, you can call `:set_bound(n)` to enable checking from that point forward, with `offset_index` initialized to 0. A `CArrayData` returned from a foreign function will have `owns_memory = false`. The caller is responsible for knowing the lifetime and layout of whatever was returned.

### Pointer Arguments and Lifetime

When passing a `CPointerData` or `CArrayData` to a C function that retains the pointer beyond the call, you must ensure the backing allocation stays alive for as long as the callee may use it. The runtime has no way to know whether the callee retains the pointer, so no automatic lifetime extension occurs.

As long as you hold a Lua variable referencing the allocation, the GC will not collect it. `retain()` is only needed if you intend to intentionally drop all your Lua references to the allocation while still needing the memory to stay alive. In that case, `retain()` pins it, and `release()` allows it to be collected again once all Lua references are also gone.

---

## Safety Policy

Validated at API boundaries:

- Invalid constructor/signature definitions.
- Invalid cast combinations.
- Null dereference.
- Known-bounds array out-of-range.
- `retain`/`release` underflow.
- Strict symbol resolution failures.
- Void instantiation.
- Invalid init values for a given type.

Intentionally unsafe and allowed:

- Wrong signatures can corrupt calls.
- Pointer and representation casts can produce invalid addresses.
- Raw pointer arithmetic has no bounds checking unless `set_bound` has been called.
- Representation casts via `c.cast` can violate effective type expectations.

---

## Examples

### Basic loading and call

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local libc = ffi.open("c")

local strlen_t = c.func(c.size_t)(c.ptr(c.char))
local strlen = c.load(libc, "strlen", strlen_t)

print(strlen(c.string("hello")):read()) -- 5
```

### Bulk symbol load

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local libc = ffi.open("c")
local lib = c.load(libc, {
    puts   = c.func(c.int)(c.ptr(c.char)),
    memcpy = c.func(c.ptr(c.void))(c.ptr(c.void), c.ptr(c.void), c.size_t),
})

lib.puts("hello from ffi")
```

### Array ownership and dependent element views

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local arr = c.new(c.array(c.int, 3), { 10, 20, 30 }) -- owns memory
local elem = arr[1] -- element view

arr = nil
collectgarbage("collect")

print(elem:read()) -- still valid
```

### Array arithmetic and bounds

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local arr = c.new(c.array(c.int, 20)) -- bound=20
local p = arr + 10
local p2 = p + 5
p2:deref():write(99)
```

In this example, `arr` has bound 20. `p = arr + 10` points to element 10 with `offset_index = 10`, and `p2 = p + 5` points to element 15 with `offset_index = 15`. Operations like `p2 + 5`, `p2 + 10`, or `p2[5]` are out of range and raise errors because they exceed the bound.

### set_bound on a foreign pointer

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local libc = ffi.open("c")
local malloc = c.load(libc, "malloc", c.func(c.voidptr)(c.size_t))

local p = malloc(20) -- raw pointer
p:set_bound(20) -- enable bounds

local p2 = p + 10

p:set_bound(nil) -- disable bounds
```

`malloc` returns a raw pointer with no bounds. `set_bound(20)` enables bounds checking with `offset_index = 0`, and `p2` advances the pointer by 10 elements. `p2 + 10` would be a runtime error because it reaches the bound. Clearing the bound disables checking again.

### Manual retain/release

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local value = c.new(c.int, 7)

value:retain() -- pin allocation
value = nil
collectgarbage("collect")

value:release() -- unpin allocation
```

The allocation stays alive after `retain()` even if all Lua references are dropped. After `release()`, it can be reclaimed once no references remain.

### Struct field views retain owner

```luau
local ffi = require("@lute/ffi")
local c = ffi.c

local Vec2 = c.struct({
    { x = c.float },
    { y = c.float },
}, { name = "Vec2" })

local v = c.new(Vec2, { x = 1.0, y = 2.0 })
local x = v.x -- field view

v = nil
collectgarbage("collect")

print(x:read()) -- still valid
```

`x` remains valid because it keeps the allocation alive.

---

## Implementation Plan and Milestones

1. Loader core (`ffi.open`, `ffi.process`, `LibraryHandle`)
2. CType core (`c.void`, primitives, `c.ptr(CType)`, `c.array`, `c.struct`, `c.func`)
3. CData core (`c.new`, allocation ownership, dependency edges)
4. Data-pointer API (`c.ptr(CData)`)
5. Memory helpers (`c.string`) and Conversions (`c.cast`)

---

## Missing Pieces and Improvement Notes

- Callback construction is currently missing from the formal API behavior text.
  - Proposed direction: allow `c.new(fnType, luaFunction)` when `fnType` is `CFunctionType`.
  - Result should be `CFunctionData` representing a C-callable callback trampoline.
  - Required constraint: callback execution must always happen on the Luau main thread.
    - If foreign code calls the callback on another thread, the runtime should enqueue the invocation onto the main thread event loop and block/wait according to callback policy.
- Vararg functions are not yet formally specified.
  - Proposed direction: support varargs by allowing `c.func(resultType)(arg1Type, arg2Type, ..., c.vararg)` construction.
