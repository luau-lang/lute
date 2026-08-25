# debug

`lute debug serve` allows you to debug your Luau code in a development environment/IDE of your choosing. This command implements the Debug Adapter Protocol, currently over an stdio pipe, which you can then connect to your IDE to enable debugging capabilities in that IDE. For VSCode, this Lute debugger will come in-built into the `Mandolin` extension, when released. Otherwise, feel free to connect your development environment to Lute with whatever DAP capability it supports (e.g. `dap-mode` for Emacs).

We currently implement:
* setting and removing breakpoints (including dynamically changing breakpoints during code execution) 
* stepping into, out of, and over code
* pausing and continuing code execution
* inspecting across multiple coroutines, stack frames, and variables
* redirecting `print` output
* debugging across multiple Luau files that were imported via `require`
* evaluation of Luau expressions within a given stack frame 

We also create the `lute/debugger` library that allows for Luau scripts to debug other scripts. Our DAP capabilities are implemented on top of this library. For more information, see [lute/debugger](#lutedebugger).

## Usage

```bash
lute debug serve
```

## Options

### `-h, --help`

Show a help message.

## lute/debugger

Besides the command above, there is also now a `lute/debugger` library so that you can write Luau scripts that have the capability to debug other Luau scripts. For a complete API, read the [reference](../reference/lute/debugger.md).

First, to get debugging capabilities, construct your own `Target` object with `newTarget`. Then, you can use the variety of methods of this `Target` object to debug your code! 

For example, before launching a debuggee, you can `setBreakpoint` and `removeBreakpoint`. When launching a debuggee, you can configure callbacks like `onBreakpointHit` to be informed when certain events occur on the debuggee. Within these callbacks, you can then perform a variety of actions, such as check if an expression value equals what you expect. 

Generally, when the code is paused, you are able to:
* get information about the currently running coroutines with `getThreads`, `getMainThread`, and `getStoppedThread`
* drill into stack frames and variables with `getStackTrace` or `getVariables`.
* evaluate expression dynamically with `evaluateExpression`
* perform `stepOver`, `stepInto`, and `stepOut` to move to the next line of code you want

After pausing code, remember to run `continueProcess` to restart the execution of the debuggee.
