local ffi = require("@lute/ffi")

print(ffi.c.testadd(2, 3)) -- 5
print(ffi.c.testadd(2 ^ 32, 2 ^ 31)) -- 0
