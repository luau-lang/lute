# Lute Lint

Linters are tools for statically analyzing code to warn programmers about common pitfalls they may be falling into or to nudge them away from discouraged coding practices.
`lute lint` is a programmable linter for Luau code, shipped as part of Lute.
It is _programmable_ meaning that you can write a new lint rule for your Luau code _in Luau_.
In addition, it is built on top of the official Luau language stack, meaning that it uses the same parser that Roblox does, unlike 3rd party linters, which use custom parser implementations.

## Usage

`lute lint` can be invoked by calling `lute lint <LUAU FILE>` or `lute lint <FOLDER WITH LUAU FILES>` (use `lute lint --help` for more uses).
`lute lint` comes with a set of default lint rules which will run automatically when it is called.
This collection of builtin default lint rules is under active development.
We're also working on [Mandolin](https://github.com/luau-lang/mandolin), a VSCode extension to surface lint violations in the editor, rather than just on the command line.

## Contact

Both `lute lint` and Mandolin are under active development. If you run into any problems or have any questions, feel free to reach out to skanosue@roblox.com or the rest of the Luau team!
