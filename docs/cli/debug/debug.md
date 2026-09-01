# debug

`lute debug serve` allows you to debug your Luau code in a development environment/IDE of your choosing. This command implements the Debug Adapter Protocol, currently over an stdio pipe, which you can then connect to your IDE to enable debugging capabilities in that IDE. For VSCode, this Lute debugger will come in-built into the `Mandolin` extension, when released. Otherwise, feel free to connect your development environment to Lute with whatever DAP capability it supports (e.g. `dap-mode` for Emacs).

We currently implement:
- setting and removing breakpoints (including dynamically changing breakpoints during code execution)
- stepping into, out of, and over code
- pausing and continuing code execution
- inspecting across multiple coroutines, stack frames, and variables
- redirecting `print` output
- debugging across multiple Luau files that were imported via `require`
- evaluation of Luau expressions within a given stack frame
- adding conditional and hit conditional breakpoints as well as logpoints
- stopping at both uncaught and caught exceptions
- setting variables/expressions to the value of another Luau expression

We also create the `lute/debugger` library that allows for Luau scripts to debug other scripts. Our DAP capabilities are implemented on top of this library. For more information, see [lute/debugger](#lutedebugger).

## Usage

```bash
lute debug serve
```

## Options

### `-h, --help`

Show a help message.

## Connecting to the VS Code Mandolin extension

Roblox publishes the Mandolin extension for VS Code to surface Lute features. For example, launching the debugger in VS Code will automatically run `lute debug serve` for you.

You can take these steps to use the debugger in Mandolin.

1. Once you are inside your extension, if you have a `foreman.toml` file in your workspace, it should automatically detect that version of Lute. Otherwise, you can manually point to your Lute executable through the `mandolin.luteExecPath` setting. 
2. Once you are ready to start debugging, you may have to click `Add Configuration` in the `Run and Debug` window or click `create a launch.json file`. This will take you to a `launch.json`. 
3. Trying to add a configuration should prompt you with a list of autocompletions. Select the autocompletion called `Lute Debug: Launch`.
4. This default configuration should allow you to start debugging your Luau files!

## lute/debugger

Besides the command above, there is also now a `lute/debugger` library so that you can write Luau scripts that have the capability to debug other Luau scripts. For a complete API, read the [reference](../../lute/debugger). If you want a thorough understanding of the debugger, feel free to look at the [architecture](ARCHITECTURE.md).

First, to get debugging capabilities, construct your own `Target` object with `newTarget`. Then, you can use the variety of methods of this `Target` object to debug your code! 

For example, before launching a debuggee, you can `setBreakpoint` and `removeBreakpoint`. When launching a debuggee, you can configure callbacks like `onBreakpointHit` to be informed when certain events occur on the debuggee. Within these callbacks, you can then perform a variety of actions, such as check if an expression value equals what you expect. 

Generally, when the code is paused, you are able to:
- get information about the currently running coroutines with `getThreads`, `getMainThread`, and `getStoppedThread`
- drill into stack frames and variables with `getStackTrace` or `getVariables`.
- evaluate expression dynamically with `evaluateExpression`
- perform `stepOver`, `stepInto`, and `stepOut` to move to the next line of code you want

After pausing code, remember to run `continueProcess` to restart the execution of the debuggee.
