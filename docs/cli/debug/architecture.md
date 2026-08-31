# Debugger Architecture

## Summary

Our debugger is mostly built around the `lute/debugger` library, whose internals are written in C++ at [debug_internals.cpp](../../../lute/debug/src/debuginternals.cpp) and whose Luau bindings are exposed at [debug.cpp](../../../lute/debug/src/debug.cpp). This library's API can be found at this [reference document](../../reference/lute/debugger.md). 

On top of this library, we implement a DAP server at [dap.luau](../../../lute/cli/commands/debug/dap.luau). That allows this debugger to connect to any development environment that also implements the DAP protocol, such as VS Code, Emacs, Neovim, and more.

## Architecture

In our debugger, we access the target script through the `Target` object that is returned by `debugger.

The `Target` object depends on two Lute runtimes: the parent runtime, which it is currently running on, and a child runtime which is spawns.

Generally, the lifetime of a `Target` object involves manipulating the child runtime to add breakpoints, continue or stop execution, or perform inspection. Moreover, before launching the debuggee script, the user can register certain event handlers in response to events that happen in the debuggee. For example, `onBreakpointHit` will run after a breakpoint is hit on the debuggee.

### Callbacks

While the user should only ever see their defined event handlers running, these is actually two levels of callbacks. In particular, there are callbacks (`debugbreak`, `debugstep`, `debuginterrupt`) in built into the Luau VM. Mostly these callbacks are reserved for tracking internal state within `Target`. Note that they are running inline/synchronously on the Luau VM of the **child**. These callbacks do have a pointer to the C++ representation of the `Target` object though, which allow them to manipulate the `Target` for tracking internal state.

The user-defined event handlers are defined in Luau and are actually a second level of callbacks that we wish to run on the **parent** Runtime. They need to run on the parent Runtime because their code deals with objects on the debugger script, not the debuggee script. Thus, the VM callbacks actually have a step where they schedule the user-defined event handlers to eventually run on the parent runtime. This asynchronous scheduling behavior is actually specified only in [debug.cpp](../../../lute/debug/src/debug.cpp). 

Note: If you were writing pure C++ code for your event handlers, as in the tests [here](../../../../lute/tests/src/debug.test.cpp), your event handlers would actually run inline as well on the child VM. However, we can't really do that within our actual `lute/debugger` package where the event handlers are written in Luau.

### Executing on the Child Runtime



## Testing
Testing for the C++ code is found at [debug_test.cpp](../../../../lute/tests/src/debug.test.cpp). Testing for the Luau bindings is found at [debugger.test.luau](../../../../lute/tests/lute/debugger.test.luau). The C++ tests are designed to be the most comprehensive in terms of edge case coverage but it remains worthwhile to also test the bindings to make sure that they are correct.

Additionally, it is worthwhile to test separately on Luau because in C++ tests, the user-defined event handlers will run inline with the rest of the C++ code. In Luau, these event handlers are instead scheduled as coroutines onto the parent runtime. This asynchronous scheduling is worth testing. 

There is also basic testing for the DAP script at [debug.test.luau](../../../../lute/tests/cli/debug.test.luau). Unfortunately, because of the asynchronous way that event handlers work with `lute/debugger`, these tests remain limited in scope.
