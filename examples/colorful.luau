local richterm = require("@batteries/richterm")

print(richterm.red("This is red text!"))
print(richterm.bgRed("This is red background!"))
print(richterm.bold("This is bold text!"))
print(richterm.underline("This is underlined text!"))
print(richterm.dim(richterm.italic("This is dim italic text!")))

print(richterm.red(`red({richterm.blue(`blue({richterm.green("green")})`)})`))

print(richterm.combine(richterm.red, richterm.bold)("This is bold red text!"))
