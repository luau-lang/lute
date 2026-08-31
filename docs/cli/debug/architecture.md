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

The user-defined event handlers are defined in Luau and are actually a second level of callbacks that we wish to run on the **parent** Runtime. They need to run on the parent Runtime because their code deals with objects on the debugger script, not the debuggee script. Thus, the VM callbacks actually have a step where they schedule the user-defined event handlers to eventually run on the parent runtime (note: this scheduling only occurs when the `Runtime` is completely stopped for safety reasons). This asynchronous scheduling behavior is actually specified only in [debug.cpp](../../../lute/debug/src/debug.cpp). 

Note: If you were writing pure C++ code for your event handlers, as in the tests [here](../../../../lute/tests/src/debug.test.cpp), your event handlers would actually run inline as well on the child VM. However, we can't really do that within our actual `lute/debugger` package where the event handlers are written in Luau.

### Executing on the Child Runtime

The child runtime now has a debug mode, allowing for it to be stopped and continued as prompted by the debugger. There are two mechanisms for stopping, one used when the current coroutine is in a yieldable state and one when it is not (e.g. it is in the middle of an error handler).

In the yieldable mechanism, we first yield the current coroutine we are running. We perform this by calling `lua_break()` in one of the debug VM callbacks. This informs the Runtime that the current coroutine that has run into this callback needs to be yielded. We also call `Runtime::stopDebug()`. This prevents the Runtime from running any additional coroutines by using a condition variable on the boolean `debugStopped`. In particular, in `Runtime::runToCompletion()`, in debug mode, we block on waiting for a continuation request before running another coroutine. Additionally, as mentioned before, callbacks must be ran when the Runtime is stopped. We thus run all pending callbacks after the current coroutine has been de-queued.

If we detect that the current coroutine is not yieldable, we instead simply wait on the condition variable set inside the Runtime in `stopDebug()`. Since the debug Luau VM callback is running inline in the child Runtime, this effectively stalls the current coroutine from running any more instructions. Additionally, the current coroutine does not yield, so no additional coroutines can be enqueued on. In this case, we are paused inline within the coroutine, so we can also run all callbacks inline within our debug Luau VM callback.

We default to yielding our coroutine because it lets the coroutine suspend cleanly rather than leaving the thread's call stack stuck to wherever the breakpoint happend to fire in the middle of a coroutine. Yielding is safer and is built on top of Runtime functionality. The non-yieldable pathway exists so we can stop in all possible cases.

In order to continue running our process, if we are in a yieldable state, we enqueue the currently stopped thread to the be the next thread to run. Under all cases, we call `continueDebug()` on the Runtime, which notifies everybody waiting on the condition variable that we can continue running coroutines. 

### Inspection

We inspect through the following process. First, we observe coroutines. Then, per coroutine, we observe a stack trace. Then, into a stack trace, we can drill into `VariableScopes`, which are grouping of variables. Right now, the only scopes are `Global`, `Local`, `Upvalue`, and `Table`. `Table` is only used internally and is not available to external users. From these scopes, you can inspect into variables, including nested tables.

Coroutine creation and garbage collection is tracked by the `userthread` Luau VM callback (which we set in `Target::installThreadCallback()`). Completed coroutines may not necessarily be garbage collected yet. However, completed coroutines are still not shown by `Target::getThreads()`. Each coroutine receives a unique ID number that we use to track it across its lifetime.

## Testing
Testing for the C++ code is found at [debug_test.cpp](../../../tests/src/debug.test.cpp). Testing for the Luau bindings is found at [debugger.test.luau](../../../tests/lute/debugger.test.luau). The C++ tests are designed to be the most comprehensive in terms of edge case coverage but it remains worthwhile to also test the bindings to make sure that they are correct.

Additionally, it is worthwhile to test separately on Luau because in C++ tests, the user-defined event handlers will run inline with the rest of the C++ code. In Luau, these event handlers are instead scheduled as coroutines onto the parent runtime. This asynchronous scheduling is worth testing. 

There is also basic testing for the DAP script at [debug.test.luau](../../../tests/cli/debug.test.luau). Unfortunately, because of the asynchronous way that event handlers work with `lute/debugger`, these tests remain limited in scope.
