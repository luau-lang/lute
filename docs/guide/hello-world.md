---
order: 3
---

# Hello World!

We're going to walk through the creation of a simple program using Lute. To
start with, create a folder for your project with:
```bash
mkdir hello-world
cd hello-world
```

Create a file in this project with:
```bash
touch main.luau
```

Before we continue, let's ensure that we setup a good autocomplete experience
for your favorite editor of choice. Run:
```bash
lute setup
```

This will add some files to a folder called `.lute/`  in your home directory.
These type definition files are then made available to `luau-lsp`, the most
popular Luau Language Server, in order to provide high quality autocomplete and
typechecking.

Finally, open up the file `main.luau` and add:
```luau
print("Hello World")
```

You can now run this program by running:
```bash
lute run main.luau
```

or just:
```bash
lute main.luau
```

Note, that any Luau script can be run like this, not just a file named `main`. 

In the next chapter, we're going to see how we can use some of the tools Lute
provides to help you write some simple programs.
