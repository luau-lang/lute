Lute [![CI](https://github.com/asynchronousai/lute/actions/workflows/ci.yml/badge.svg)](https://github.com/asynchronousai/lute/actions/workflows/ci.yml)
====

Lute is a standalone runtime for general-purpose programming in [Luau](https://luau.org), and a collection of optional extension libraries for Luau embedders to include to expand the capabilities of the Luau scripts in their software.
It is designed to make it readily feasible to use Luau to write any sort of general-purpose programs, including manipulating files, making network requests, opening sockets, and even making tooling that directly manipulates Luau scripts.
Lute also features a standard library of Luau code, called `std`, that aims to expose a more featureful standard library for general-purpose programming that we hope can be an interface shared across Luau runtimes.

Lute is still very much a work-in-progress, and should be treated as pre-1.0 software without stability guarantees for its API.
We would love to hear from you about your experiences working with other Luau or Lua runtimes, and about what sort of functionality is needed to best make Luau accessible and productive for general-purpose programming.

### Lute Libraries

The Lute repository fundamentally contains three sets of libraries. These are as follows:
- `lute`: The core runtime libraries in C++, which provides the basic functionality for general-purpose Luau programming.
- `std`: The standard library, which extends those core C++ libraries with additional functionality in Luau.
- `batteries`: A collection of useful, standalone Luau libraries that do not depend on `lute`.

Contributions to any of these libraries are welcome, and we encourage you to open issues or pull requests if you have any feedback or contributions to make.

## Documentation
### `@std/table`
- `table.map(table: table, callback: (value: any) -> any): table`
Transforms a table with a modifier function applied on every value.
```lua
table.map({1, 2, 3}, function(value)
    return value * 2
end) -- {2, 4, 6}
```
- `table.filter(table: table, callback: (value: any) -> boolean): table`
Filters a table with a predicate function applied on every value.
```lua
table.filter({1, 2, 3}, function(value)
    return value % 2 == 0
end) -- {2}
```
- `table.fold(table: table, callback: (accumulator: any, value: any) -> any, initial: any): any`
Folds a table with an accumulator function applied on every value.
```lua
table.fold({1, 2, 3}, function(accumulator, value)
    return accumulator + value
end, 0) -- 6
```
- `table.isArray(table: table): boolean`
Checks if a table is an array.
```lua
table.isArray({1, 2, 3}) -- true
```
- `table.union(table1: table, table2: table): table`
Merges two tables into one.
```lua
table.union({1, 2}, {3, 4}) -- {1, 2, 3, 4}

table.union({a = 1}, {b = 2}) -- {a = 1, b = 2}
```
- `table.count(table: table): number`
Counts the number of elements in a table. For arrays use `#t`, this
is useful for dictionaries.
```lua
table.count({a = 1, b = 2}) -- 2
```
- `table.reverse(table: table): table`
Reverses the order of elements in a table.
```lua
table.reverse({1, 2, 3}) -- {3, 2, 1}
```
- `table.difference(table1: table, table2: table): table`
Returns the difference between two tables.
```lua
table.difference({1, 2, 3}, {2, 3, 4}) -- {1}
```
- `table.contains(table: table, value: any): boolean`
Checks if a table contains a subtable.
```lua  
table.contains({1, 2, 3}, {2, 3}) -- true
```
- `table.set(table: table): table`
Removes duplicate values from a array.
```lua
table.set({1, 2, 2, 3}) -- {1, 2, 3}
```
## Build
- `python ./tools/luthier.py fetch lute` (Download submodules)
- `python ./tools/luthier.py configure lute --config=debug` (Configure the build)
- `python ./tools/luthier.py build lute --config=debug` (Build the project)
> - Replace `debug` with `release` for a release build
> - You may need to replace `python` with `python3` depending on your system
> - You may need to add `--c-compiler /usr/bin/clang --cxx-compiler /usr/bin/clang++` to the `configure` & `build` commands with your compiler paths.