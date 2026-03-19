---
order: 4
---

# Writing a Guessing Game

### Introduction
We're going to walk through how you might build a small guessing game using Lute. Like we did in the previous chapter, make a new folder
for this project, along with a script called `main.luau`.

This is a program that will take a user's input and compare it to a secret number that the program will generate. The user will then be prompted to input their guess,
and the program will tell them "Too high!" or "Too low!" until they guess right.


### Using the Lute standard library
To start, we'll need some way of getting user input. Thankfully, Lute provides a utility for this in the [`io`](../reference/std/io) library. In `main.luau`, add:
```luau
local io = require("@std/io")
```

This is a require statement - the `@std` is an alias, and `io` is the name of the library. The `@std` and `@lute` aliases, have been reserved by Lute to refer to the standard library and Lute internal libraries respectively. You can `require` any set of scripts that return values, even ones you write locally.
This module returns a table with one field - `input`, which waits for the user to type something into the terminal. We can assign this table a value so we can refer to it later.

```luau
local io = require("@std/io")

print("Say something! ")
local input : string = io.input()
print(input)
```

Now, run this with `lute main.luau`. The program will pause until you input something, then print it back to you:
```bash
lute main.luau
>>> Say something! hello
hello
```

### Generating random numbers with Luau builtins
Let's move on to implementing this guessing game. We need to generate a random number, which Luau already provides via the `random` function on the `math` table. 

This highlights an important distinction between Luau and Lute - **Luau** provides builtin functions that operate on the primitive types, e.g. `string`, `math`, `buffer`, etc, while **Lute** provides utilities for interacting with the outside world e.g. user input, the file system, http requests. In this case, the `math.random` function is provided by Luau and will suffice for our purposes. We'll set a limit of 100, so that math.random will not generate numbers that are too small.

```luau
local io = require("@std/io")
local randomNumber : number = math.random(100)

print("Guess a number: ")
local input : string = io.input()
local guess = tonumber(input)
```

So now we have the guessed value - we should try to let the user know if they got it right or wrong. 

::: info
The output of `input()` is a string, and we want to compare it to a number. If you try to ask `x \< randomNumber`, this won't work correctly. We'll want to convert this using the [`tonumber`](https://www.lua.org/manual/5.1/manual.html#pdf-tonumber) function.
:::


```luau
local io = require("@std/io")
local randomNumber = math.random(100)

print("Guess a number: ")
local input : string = io.input()


if guess > randomNumber then
    print("Too high!")
elseif guess < randomNumber then
    print("Too low!")
else
    print("Got it!")
end
```

So far so good! Ideally though, the user would be able to guess multiple times - in this example, the user has one chance. Let's even the odds a bit - we'll need to re-prompt the user if they got it wrong and exit out if they guess right.

### Adding a Loop

```luau
local io = require("@std/io")
local randomNumber = math.random(100)

local guessedRight = false
while not guessedRight do
    print("Guess a number: ")
    local input = io.input()
    local guess = tonumber(input)
    if guess > randomNumber then
        print("Too high!")
    elseif guess < randomNumber then
        print("Too low!")
    else
        print("Got it!")
        guessedRight = true
    end
end
```

You can see that here, we've added a variable and a loop to check whether or not the user got the guess right. After checking at the beginning of the loop, we prompt them, they respond, and if they get it right, we update the value of guessedRight. Try running this program to see if you can guess the number!

### Input Validation
We glanced over what happens if the input provided by the user isn't a number. In this case, `tonumber` will return nil - and we forgot to check for that. Let's add that right now!

```luau
local io = require("@std/io")
local randomNumber = math.random(100)

local guessedRight = false
while not guessedRight do
    print("Guess a number: ")
    local input = io.input()
    local guess : number? = tonumber(input)
    if not guess then
        print(`Not a number: {input}`)
        continue
    end
    if guess > randomNumber then
        print("Too high!")
    elseif guess < randomNumber then
        print("Too low!")
    else
        print("Got it!")
        guessedRight = true
    end
end
```
::: info
Notice the `continue` in the `if not guess then` check. If a user types "hello" instead of "5", tonumber returns nil. Without this check, the program would crash. Using continue allows us to skip the rest of the loop and ask the user again.
:::

### Handling command line arguments
To finish up, let's see how we can pass arguments to programs in Lute to configure their behaviour. 

For our game, let's try to configure the maximum size of the random number being generated. In Luau, command line arguments can be unpacked at the top of the script using the syntax (`...`), which unpacks the variadic list of arguments passed to the script. For example:

```luau
local args = {...} -- ... are the arguments passed to this script, and they're being unpacked into an array.
```

The first argument, stored in `args[1]` is always the script name, with the remaining arguments following after. If the user passes a `--max <number>` argument, we should set the maximum value of the number being generated to that value, defaulting to a 100. We can write a small helper function to validate this information:

```luau
local io = require("@std/io")
local args = {...}
local function getArgs(args) : number
    if #args < 3 then
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
...
```

Here, we've written a function that will error when the user inputs not enough arguments, the number passed to the `--max` argument, or the default value of 100 in all other cases. Putting it all together gets us:

```luau
local io = require("@std/io")
local args = { ... }

local function getArgs(args) : number
    if #args == 2 then
        error("Didn't pass enough arguments")
    elseif #args < 2 then
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

local maxValue = getArgs(args) -- figure out what the --max <number> argument is or use a 100
local randomNumber = math.random(maxValue)

local guessedRight = false
while not guessedRight do
    print("Guess a number: ")
    local input = io.input()
    local guess : number? = tonumber(input)
    if not guess then
        print(`Not a number: {input}`)
        continue
    end
    if guess > randomNumber then
        print("Too high!")
    elseif guess < randomNumber then
        print("Too low!")
    else
        print("Got it!")
        guessedRight = true
    end
end
```

If you try this program out now, you should be able to run it like: 
```bash
lute main.luau --max 50
```
to re-run the guessing game with maximum 50 guesses.

### Conclusion
Congratulations! You've build your first Lute program. In this chapter we covered:
1. How to use `require` to use standard library functionality
2. The difference between functions and libraries provided by Lute and Luau 
3. How to write a program that talks to the outside world (your terminal)
4. How to do some basic input validation
5. The structure and parsing of command line arguments in Luau programs.

## TODOS:
- Perhaps implement a lute new \<proj\> command, that creates a main.luau file, setups a luaurc, creates a tests directory?