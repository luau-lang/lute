local colorful = require("@batteries/colorful")

print(colorful.red("This is red text!"))
print(colorful.bgRed("This is red background!"))
print(colorful.bold("This is bold text!"))
print(colorful.underline("This is underlined text!"))
print(colorful.dim(colorful.italic("This is dim italic text!")))

print(colorful.red(`red({colorful.blue(`blue({colorful.green("green")})`)})`))

print(colorful.combine(colorful.red, colorful.bold)("This is bold red text!"))
