local hello = require("./build/libhello")

print(hello.world())
print(`1 + 2 = {hello.add(1, 2)}`)
print(hello == require("./build/libhello"))
