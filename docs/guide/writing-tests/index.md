---
order: 5
---

# Writing Tests

As mentioned [here](../dev-tooling/index), `lute` features a builtin utility
for discovering and running tests. In this chapter, we'll see how you can write
tests against this framework and execute them. This can help you improve your
confidence in the correctness of your code. Specifically we'll look at the code
from the guessing game chapter, and test the code that handles argument parsing.

### Setting up your project

To get started, set up a project structure that has these files:
```
project/
    utils.luau
    args.test.luau
```

Inside of `utils.luau`, add the following code:
```luau
local function getArgs(args) : number
    if #args == 2 then
        error("Didn't pass enough arguments")
    elseif #args \< 2 then
        return 100
    else
        if args[2] == "--max" then
            local argument = tonumber(args[3])
            if argument then
                return argument
            end
        end
    end
    return 100
end

return table.freeze({ getArgs = getArgs})
```

This defines a module that exports a single frozen (i.e. immutable or read-only) table that has a
single function on it --- the getArgs function from the last chapter. 

This function (purportedly) parses a set of command line arguments and either
errors, returns a number if a --max \<number\> was passed, or 100. Let's try to test this! 


### Using @std/test
First, open up `args.test.luau` in your favorite text editor.

We will need to require `@std/test` as well as the code we are trying to test:

```luau
local test = require("@std/test")
local utils = require("./utils")
```

Next up, a simple test case:
```luau
local test = require("@std/test")
local utils = require("./utils")

test.case("maxOverridesValue", function(asserts)
    -- What should happen here ?
end)
```

To start, let's write a simple test that asserts that when `getArgs` is invoked
with a `--max` argument, that it returns that value as a number. In order to
match the behaviour of the command line in our testing code, we'll want to
include an extra argument with the name of the script being called.

```luau
local test = require("@std/test")
local utils = require("./utils")

test.case("maxOverridesValue", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--max", "20"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(20, result)
end)
```

:::info 
Command line arguments are conventionally passed with the following
format: \<name of program\> <rest of the arguments...\>

For example, when you run:
```bash
lute args.test.luau
```
your shell will pass `lute`, `args.test.luau` as the arguments to `lute`.

Following that same convention, `lute` will pass `args.test.luau`as well as the
remainder of the arguments as the first argument to the script being run. 
:::

### Running test cases
To run this test, from the root of your project directory run `lute test`. You
should see output like this:
```bash
──────────────────────────────────────────────────
Results: 1 passed, 0 failed of 1
```

Excellent! Our first test passed, but we should write more.

### Adding more tests

In this next test, we'll add a test for the case where we don't pass a `--max`
argument:
```luau
local test = require("@std/test")
local utils = require("./utils")

...

test.case("noPassingMax", function(asserts)
    local fakeArgs = { "fakeScript.luau"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(100, result)
end)
```

Great! It looks like these tests pass. Let's keep going! 

What happens if you pass `--max` without a corresponding number argument? If we
look at the implementation of the `getArgs` function, it looks like it raises an
exception, using the builtin Luau function `error`. Raising an exception is a
reasonable thing to do here, and we'll want to test that our program correctly
raises an exception when `--max` doesn't get passed a number.

In order to assert this behaviour we'll need to use the `errors` assertion.

```luau
local test = require("@std/test")
local utils = require("./utils")
...

test.case("noArgToMax", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--max"}
    assert.errors(function()
        utils.getArgs(fakeArgs)
    end)

end)
```
This assertion will run the code `utils.getArgs(fakeArgs)`. If it raises an
error, then the assertion will intercept it and succeed. If not, the assertion
will fail, which will be reported as a failed test case.

### Using Test Suites to organize tests
While we're at it, we can also wrap all of these tests into a single test
suite, which will group these tests together. Test suites also allow you to use
lifecycle methods like `beforeeach/all`, `aftereach/all` to control setup and
tear down for tests.

```luau
local test = require("@std/test")
local utils = require("./utils")

test.suite("GetArgsTest", function(suite)
	suite:case("maxOverridesValue", function(asserts)
		local fakeArgs = { "fakeScript.luau", "--max", "20" }
		local result = utils.getArgs(fakeArgs)

		asserts.eq(20, result)
	end)

	suite:case("noPassingMax", function(asserts)
		local fakeArgs = { "fakeScript.luau" }
		local result = utils.getArgs(fakeArgs)

		asserts.eq(100, result)
	end)

	suite:case("noArgToMax", function(asserts)
		local fakeArgs = { "fakeScript.luau", "--max" }
		asserts.errors(function()
			utils.getArgs(fakeArgs)
		end)
	end)

end)
```

Re-running the tests produces:
```bash
──────────────────────────────────────────────────
Results: 3 passed, 0 failed of 3
```

:::info You can re-run individual or groups of tests using:
```bash
lute test -c caseName # run tests with the name caseName
lute test -s suiteName # run all tests with the name suiteName
lute test tests/path/to/.test.luau # run the tests in a particular file
```
:::

:::info
One situation where you might to use the aforementioned test suite lifecycle methods is when your tests operate on files on
files in a temporary directory. For example, testing that some code can create a
set of files. When subsequent tests execute, they may be operating in a
directory filled with files leftover from a previous test.

In this situation, you could use the `beforeeach` method to execute some cleanup
of the temporary directory:

```luau
local test = require("@std/test")
local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")

-- a temporary directory for tests to operate in
local testDir = path.join(system.tmpdir(), "test")

test.suite("FileCreation", function()
    test.beforeeach(function()
        --Deletes the contents of the test directory before each test
        fs.removedirectory(testDir, {recursive = true})
        --Recreates the directory so it exists for the next test to use it
        fs.createdirectory(testDir)
    end)
end)

```
:::

### Fixing failed tests
So far, so good, let's take at what happens when a test case fails! Try this one out:
```luau
suite:case("unsupportedArgument", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--what", "foo"}
    asserts.errors(function()
        utils.getArgs(fakeArgs)
    end)
end)
```

If you run this, you'll see that it doesn't throw, and `lute test` provides a
stacktrace showing what went wrong:
```
Failures:

  FAIL getArgsTest.unsupportedArgument
        .../args.test.luau:26
        errors: function: 0x000000012f859740 did not throw error.
```

This shows us a bug in our `getArgs` implementation - what if the user passes the
right number of arguments but supplies an unsupported option? In this case, the
fix is to error in the case that the second argument to `getArgs` isn't `--max`:
```luau
local function getArgs(args) : number
    if #args == 2 then
        error("Didn't pass enough arguments")
    elseif #args \< 2 then
        return 100
    else
        if args[2] == "--max" then
            local argument = tonumber(args[3])
            if argument then
                return argument
            end
        else
            error(`Expected flag --max, but got {args[2]}`)
        end
    end
    return 100
end
```

If you try to re-run the tests, they should all pass now.