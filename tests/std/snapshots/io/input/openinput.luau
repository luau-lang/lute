local fs = require("@std/fs")
local io = require("@std/io")

-- Reproduces issue #1172: open a file whose name comes from io.input(). If the
-- trailing terminator were not stripped, fs.open would fail on the bogus name.
local name = io.input()
local ok, contents = pcall(fs.readFileToString, name)
io.write(if ok then contents else `could not open: {name}`)
