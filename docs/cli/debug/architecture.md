# Debugger Architecture

## Summary

Our debugger is mostly built around the `lute/debugger` library, whose internals are written in C++ at `lute/debug/src/debuginternals.cpp` and whose Luau bindings are exposed at `lute/debug/src/debug.cpp`. This library's API can be found at this [reference document](../../lute/debugger). 

On top of this library, we implement a DAP server at `lute/cli/commands/debug/dap.luau`. That allows this debugger to connect to any development environment that also implements the DAP protocol, such as VS Code, Emacs, Neovim, and more.

## Architecture

In our debugger, we access the target script through the `Target` object that is returned by `debugger.newTarget()`.

The `Target` object depends on two Lute runtimes: the parent runtime, which it is currently running on, and a child runtime which it spawns.

Generally, the lifetime of a `Target` object involves manipulating the child runtime to add breakpoints, continue or stop execution, or perform inspection. Moreover, before launching the debuggee script, the user can register certain event handlers in response to events that happen in the debuggee. For example, `onBreakpointHit` will run after a breakpoint is hit on the debuggee.

### Callbacks

While the user should only ever see their defined event handlers running, these are actually two levels of callbacks. In particular, there are callbacks (`debugbreak`, `debugstep`, `debuginterrupt`) built into the Luau VM. Mostly these callbacks are reserved for tracking internal state within `Target`. Note that they are running inline/synchronously on the Luau VM of the **child**. These callbacks do have a pointer to the C++ representation of the `Target` object though, which allow them to manipulate the `Target` for tracking internal state.

The user-defined event handlers are defined in Luau and are actually a second level of callbacks that we wish to run on the **parent** Runtime. They need to run on the parent Runtime because their code deals with objects on the debugger script, not the debuggee script. Thus, the VM callbacks actually have a step where they schedule the user-defined event handlers to eventually run on the parent runtime (note: this scheduling only occurs when the `Runtime` is completely stopped for safety reasons). This asynchronous scheduling behavior is actually specified only in `lute/debug/src/debug.cpp`. 

Note: If you were writing pure C++ code for your event handlers, as in the tests `tests/src/debug.test.cpp`, your event handlers would actually run inline as well on the child VM. However, we can't really do that within our actual `lute/debugger` package where the event handlers are written in Luau.

### Executing on the Child Runtime

The child runtime now has a debug mode, allowing for it to be stopped and continued as prompted by the debugger. There are two mechanisms for stopping, one used when the current coroutine is in a yieldable state and one when it is not (e.g. it is in the middle of an error handler).

In the yieldable mechanism, we first yield the current coroutine we are running. We perform this by calling `lua_break()` in one of the debug VM callbacks. This informs the Runtime that the current coroutine that has run into this callback needs to be yielded. We also call `Runtime::stopDebug()`. This prevents the Runtime from running any additional coroutines by using a condition variable on the boolean `debugStopped`. In particular, in `Runtime::runToCompletion()`, in debug mode, we block on waiting for a continuation request before running another coroutine. Additionally, as mentioned before, callbacks must be run when the Runtime is stopped. We thus run all pending callbacks after the current coroutine has been de-queued.

If we detect that the current coroutine is not yieldable, we instead simply wait on the condition variable set inside the Runtime in `stopDebug()`. Since the debug Luau VM callback is running inline in the child Runtime, this effectively stalls the current coroutine from running any more instructions. Additionally, the current coroutine does not yield, so no additional coroutines can be enqueued on. In this case, we are paused inline within the coroutine, so we can also run all callbacks inline within our debug Luau VM callback.

We default to yielding our coroutine because it lets the coroutine suspend cleanly rather than leaving the thread's call stack stuck to wherever the breakpoint happened to fire in the middle of a coroutine. Yielding is safer and is built on top of Runtime functionality. The non-yieldable pathway exists so we can stop in all possible cases.

In order to continue running our process, if we are in a yieldable state, we enqueue the currently stopped thread to be the next thread to run. Under all cases, we call `continueDebug()` on the Runtime, which notifies everybody waiting on the condition variable that we can continue running coroutines. 

### Breakpoints
Breakpoints have their unique ID and are set at a specific line in a specific source file. Breakpoints can be set at any point the `Target` is paused, including before the program is launched. If a breakpoint is added/deleted while the program is running, this change is not actually reflected on the debuggee until the Target is next paused. We do this because changing breakpoints requires modifying the underlying Luau bytecode, which is dangerous while the code is still running. Hitting a breakpoint fires the Luau VM `debugbreak` callback, which stops the program and schedules user event coroutines as required.

In order to install breakpoints, we record which sources are currently available to the debugger. After we add a breakpoint, if the source is available and we are paused or in the launch process, we install that breakpoint using `lua_breakpoint`. A source becomes available if it is the starting file that we launched or if it is imported through the `require` system. We intercept calls to the `require` system through `onChunkLoad()`. 

We additionally implement special types of breakpoints, including conditional breakpoints, hit conditional breakpoints, and logpoints. Conditional breakpoints use the `Target::evaluateExpression` feature to make sure an expression evaluates to a truthy value before actually stopping the program. 

Hit conditional breakpoints also use the `Target::evaluateExpression` feature but instead substitute the number of times a breakpoint has been hit (note: a hit is whenever we ran that line of code, not however many times we've stopped at that line). For a more in-depth explanation of how to specify hit conditional breakpoints, see `BreakpointConfig` at our [API](../../lute/debugger). 

Logpoints do not actually stop execution of the code. Instead, a logpoint produces a message string that is then sent to the debugger via `onLogpoint`, along with the source file and line number of where the logpoint is. This logpoint message will interpolate any expression within `{}`.

Note: the expressions contained within each of these specialized breakpoints only evaluate within the variables available at the current stack frame, not in any stack frames above it. This follows the same principles outlined for `evaluateExpression()`.

### Stepping
We have three types of stepping: step over, step into, and step out. Each of these variants relies on the same core stepping mechanism. Stepping involves setting the VM into stepping mode with `lua_singlestep()`. In this mode, after every bytecode is executed, the VM calls back using `debugstep`. In `debugstep`, we only stop our coroutine when a condition that depends on which type of stepping evaluates to true. Otherwise, we continue with normal execution.

| Type of stepping | Condition |
|---|---|
| `stepIn` | `line number != start line number \|\| stack depth != start stack depth` |
| `stepOver` | `line number != start line number && stack depth <= start stack depth` |
| `stepOut` | `stack depth < start stack depth` |

Note: If we hit a breakpoint or pause a process, stepping is stopped.

### Pausing
When trying to pause our process, we set the `debuginterrupt` callback to stop Runtime execution. This callback fires whenever we are at a safe point (i.e. a function call, a function return, or a loop jumpback). Thus, pausing of a program will eventually take effect when such a safe point is encountered.

### Output Redirection
If your program wishes to redirect output from `stdout`, you can set the `onPrint` callback during launch. With this callback you can intercept statements that call `print()`. `onPrint` receives the message that was to be printed along with the source file and line number that print was called from.

### Exceptions
We can pause the runtime on both uncaught and caught exceptions. For the sake of DAP, exception breakpoints have their own fixed IDs and thus can be returned as DAP breakpoint objects. Their mechanism however is very different than normal breakpoints. Additionally, between themselves, uncaught and caught exceptions use different pathways.

For uncaught exceptions, we actually have a callback situated in the Runtime called `onUncaughtError` that runs when we finish a coroutine that has status `LUA_ERRRUN`. This stops the runtime from any further execution through `Runtime::stopDebug()`. However, unlike normal runtime stopping, it does not need to dequeue the current executing coroutine because that has already finished executing with error. At this point, we can safely inspect into coroutines (note: the completed coroutine can never be garbage collected because we hold onto a reference to it). 

For caught exceptions, we set the native Luau VM callback `debugprotectederror`. Things are similar to other callbacks where we want to pause Luau execution, except we force ourselves to go into non-yieldable stopping. This is because currently resuming from a yielded coroutine loses any error handler that was originally associated with the coroutine. Given that we are specifically trying to deal with the `pcall` or `xpcall` case here, we thus must stop using the non-yieldable mechanism.

### Inspection

We inspect in our Luau state through the following process, which is adopted from DAP. First, we observe coroutines. Then, per coroutine, we observe a stack trace. Then, into a stack trace, we can drill into variable scopes, which are grouping of variables. From these scopes, you can inspect into variables, including nested tables. 

Threads, stack frames, variable scopes/variables all receive their own set of unique IDs. Variable scopes and variables receive the same ID space, while threads and stack frames have their own isolated ID space. These IDs help us identify what object we are inspecting into. For example, we pass in a thread ID to inform `Target::getStackTrace()` of which thread we are trying to get the stack trace from. Each coroutine receives a unique ID number that we use to track it across its lifetime. The other objects have ID numbers that are only unique to the current suspended state. Thus, these ID numbers will get reset if the `Target` is continued. For further explanation, see "Lifetime of Object References" in the [DAP overview](https://microsoft.github.io/debug-adapter-protocol/overview).

Coroutine creation and coroutine garbage collection are tracked by the `userthread` Luau VM callback (which we set in `Target::installThreadCallback()`). Completed coroutines may not necessarily be garbage collected yet. However, completed coroutines are still not shown by `Target::getThreads()`.

Note: When in debugging mode, `task.spawn()` is equivalent to `task.defer()`. The task is thus not run inline but instead deferred to be scheduled onto the runtime. Otherwise, if it did run in line, inspection would break as we could technically have multiple coroutines active at one single point in the code.

For each coroutine, we maintain a stack trace. Getting stack traces is a relatively more simple process, since we can find the stack depth of a coroutine with `lua_stackdepth`. Additionally, each stack frame is augmented with a source path, a line number, and an informative name (generally the function being called in the frame). This information is produced via `lua_getinfo`. For potentially very large stack traces, we support retrieving delayed stack trace loading (see the DAP protocol), which allows you to load the stack trace in contiguous blocks.

From each stack frame, you can inspect into scopes of variables. Scopes are not "real" objects in Luau. Instead, they are collections of variables used by the debugger so that the development environment can display its information in a more organized manner. Right now, the only scopes are `Globals`, `Locals`, `Upvalues`, and `Table`. `Table` is only used internally and is not available to external users. 

Within each variable scope, you can inspect into its variables. Variables that are not tables have their name, value, and type saved. There are separate pathways for fetching this information for which type of scope the variables are coming from, so local variables are fetched via `lua_getlocal()` and upvalues are fetched via `lua_getupvalue()` and so on. 

Variables that are tables additionally get their own ID so that a user can inspect further into them if required. Through this process of inspecting into tables, we can support multi-level nested tables, while only retrieving the necessary levels when it is needed. Because of this lazy inspection feature, we restrict the value of a table to only be a summary of its first two shallowest levels (see `printTable()`).

### Expression Evaluation

Expressions are generally evaluated within the context of a certain stack frame, and so evaluateExpression takes in a stack frame id. If this stack frame id is -1, we actually just evaluate into the global frame. When we describe evaluating within the context of a certain stack frame, this means that we only have access to the local variables, upvalues, and globals located within that stack frame. We thus exclude any available in parent stack frames, which is similar behavior to other debuggers.

The pathway for evaluating an expression is actually similar to the pathway for launching the script in so far as that the debugger needs to compile the expression, create a new thread of execution, and then run that thread. In more detail:

1. First, we compile our expression into Luau bytecode, spawn a new thread, and then load the bytecode onto that thread.
2. The debugger injects all locals and upvalues that are on our relevant stack frame onto the thread that will actually run our expression. The mechanism for injecting variables is similar to the one used to inspect variables, except we now copy the variable onto our new evaluation thread as well.
3. We deactivate our mechanisms to track breakpoints and threads along with turning off garbage collection. All of these mechanisms could lead to calling into the debugger (or changing the state of the runtime unexpectedly in the case of garbage collection) during the eval thread, which we do not want to happen.
4. We call lua_resume inline to finish executing our compiled and loaded bytecode. This is good because it runs the coroutine inline with our code, which is safe as we are paused, rather than doing scheduling. 
5. We reactivate garbage collection and our mechanisms to track bps and threads.
6. We parse the result of the expression into a variable off the stack of the evaluation thread.

### Setting Variables and Expressions
When we set a variable to the output of an expression, we are given the ID of the parent scope that may contain that variable. We then search through that scope to see if a matching variable exists. If it does, we then evaluate the RHS and get its value. We then call `setLocal`, `setUpvalue`, or simply modify the table containing that variable to actually set the variable. Notice that scopes contain which thread and level of stackframe they come from, which we then use to find the relevant stack frame to evaluate our RHS in.

Setting expressions is relatively similar to setting variables, except that the LHS can be more complicated. Additionally, `Target::setExpression` is given a stack frame ID explicitly. We first perform a search on the LHS, seeing if it is a local, upvalue, or global value. If it is, we call `Target::setVariable`. Otherwise, if the LHS resolves to a reference inside a table, we simply evaluate an expression with `LHS = RHS`. Because of the way we store tables, they are copied by reference, so evaluating this expression will change the value of the table scriptwide. Locals and upvalues are copied by value so we have to call into `setLocal` or `setUpvalue` explicitly through `setVariable`.

## Testing

Testing for the C++ code is found at `tests/src/debug.test.cpp`. Testing for the Luau bindings is found at `tests/lute/debugger.test.luau`. The C++ tests are designed to be the most comprehensive in terms of edge case coverage but it remains worthwhile to also test the bindings to make sure that they are correct.

Additionally, it is worthwhile to test separately on Luau because in C++ tests, the user-defined event handlers will run inline with the rest of the C++ code. In Luau, these event handlers are instead scheduled as coroutines onto the parent runtime. This asynchronous scheduling is worth testing. 

There is also basic testing for the DAP script at `tests/cli/debug.test.luau`. Unfortunately, because of the asynchronous way that event handlers work with `lute/debugger`, these tests remain limited in scope.
