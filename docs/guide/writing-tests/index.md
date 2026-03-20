---
order: 5
---

# Writing Tests

As mentioned [here](../dev-tooling/index), `lute` comes with a builtin utility
for discovering and running tests. In this chapter we'll see how you can write
tests against this framework and execute them. This can help you improve your
confidence in the correctness of your code. We'll look at how we could test the
code from the guessing game chapter, specifically the code that handles argument
parsing.

### Setting up your project

To get started, set up a project structure that has these files:
```
project/
    utils.luau
    tests/
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

This defines a module that exports a single frozen(immutable) table that has a
single function on it - the getArgs function from the last chapter. This
function (purportedly) parses a set of command line arguments and either errors,
returns a number if a --max \<number\> was passed, or 100. Let's try to test
this!


### Using @std/test
First, let's pull in `@std/test` and our utility file:

```luau
local test = require("@std/test")
```

Next up, a simple test case:
```luau
local test = require("@std/test")
local utils = require("../utils")

test.case("maxOverridesValue", function(asserts)
    -- What should happen here ?
end)
```

To start, let's write a simple test that asserts that when getArgs is invoked
with a `--max` argument that it returns that value as a number. To match how
command line arguments are passed, we'll explicitly pass the first argument (the
name of the script).

```luau
local test = require("@std/test")
local utils = require("../utils")

test.case("maxOverridesValue", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--max", "20"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(20, result)
end)
```


### Running test cases
To run this test, from the root of your project directory run `lute test`. You
should see output like this:
```bash
──────────────────────────────────────────────────
Results: 1 passed, 0 failed of 1
```

Excellent! Our test passed.

### Adding more tests

Let's add one more more:
```luau
local test = require("@std/test")
local utils = require("../utils")

test.case("maxOverridesValue", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--max", "20"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(20, result)
end)

test.case("noPassingMax", function(asserts)
    local fakeArgs = { "fakeScript.luau"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(100, result)
end)
```

Great! It looks like these tests pass. Now let's try something slightly more
interesting. If you pass `--max` without a corresponding number argument, we
throw an error. Let's try checking for that:
```luau
local test = require("@std/test")
local utils = require("../utils")

test.case("maxOverridesValue", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--max", "20"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(20, result)
end)

test.case("noPassingMax", function(asserts)
    local fakeArgs = { "fakeScript.luau"}
    local result = utils.getArgs(fakeArgs)

    asserts.eq(100, result)
end)

test.case("noArgToMax", function(asserts)
    local fakeArgs = { "fakeScript.luau", "--max"}
    asserts.errors(function()
			utils.getArgs(fakeArgs)
	end)
end)
```
We've used the `errors` assertions to check for the case where we haven't passed
a number to `--max`. 

### Using Test Suites to organize tests
 While we're at it, we can also wrap all of these tests into a single test
 suite, which will group these tests together. Test suites also allow you to use
 lifecycle methods like `beforeeach/all`, `aftereach/all` to control setup and
 tear down for tests.

```luau
local test = require("@std/test")
local utils = require("../utils")

test.suite("getArgsTest", function(suite)
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

### Fixing failed tests
So far so good. Let's take a look at a different test case! Try this one out:
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

This shows us a bug in our getArgs implementation - what if the user passes the
right number of arguments but supplies an unsupported option? In this case, the
fix is to error in the case that the second argument to getArgs isn't `--max`:
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