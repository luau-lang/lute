local hello = require("./build/libhello") :: any

print(hello.world())
print(`1 + 2 = {hello.add(1, 2)}`)
