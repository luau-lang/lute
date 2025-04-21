local ansi = require("@batteries/ansi")

print(ansi.red("This is red text!"))
print(ansi.bgRed("This is red background!"))
print(ansi.bold("This is bold text!"))
print(ansi.underline("This is underlined text!"))
print(ansi.dim(ansi.italic("This is dim italic text!")))
print(ansi.red(`red({ansi.blue(`blue({ansi.green("green")})`)})`))
