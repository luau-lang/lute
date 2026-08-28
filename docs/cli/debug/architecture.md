# Debugger Architecture

## Summary

Our debugger is mostly built around the `lute/debugger` library, whose internals are written in C++ at [debug_internals.cpp](../../../lute/debug/src/debuginternals.cpp) and whose Luau bindings are exposed at [debug.cpp](../../../lute/debug/src/debug.cpp). This library's API can be found at this [reference document](../../reference/lute/debugger.md). 

On top of this library, we implement a DAP server at [dap.luau](../../../lute/cli/commands/debug/dap.luau). That allows this debugger to connect to any development environment that also implements the DAP protocol, such as VS Code, Emacs, Neovim, and more.

## Features


## Testing
Testing for the C++ code is found at [debug_test.cpp](../../../../lute/tests/src/debug.test.cpp). Testing for the Luau bindings is found at [debugger.test.luau](../../../../lute/tests/lute/debugger.test.luau). The C++ tests are designed to be the most comprehensive in terms of edge case coverage but it remains worthwhile to also test the bindings to make sure that they are correct.

There is also basic testing for the DAP script at [debug.test.luau](../../../../lute/tests/cli/debug.test.luau). Unfortunately, because of the asynchronous way that event handlers work with `lute/debugger`, these tests remain limited in scope.
