-- Verifies that io.read() reads exactly one line per call when stdin is a
-- pipe or redirected file (i.e. any non-TTY path).
--
-- Previously two bugs affected the pipe/file code path:
--
-- 1. io.read() read the entire available buffer in one call rather than
--    stopping at a newline, so the first call returned multiple lines at once.
--
-- 2. io.read() passed fileno(stdin) directly to uv_pipe_open(), which took
--    ownership of the fd.  When the handle was closed after the read, fd 0
--    was closed with it, causing the second io.read() to fail.
--
-- Both bugs are now fixed: the handle is kept alive across calls (uv_read_stop
-- between reads, uv_close only on EOF) and input is accumulated line-by-line.
--
-- Run with piped input to trigger the non-TTY code path:
--   printf "first\nsecond\n" | lute examples/read_twice_bug.luau
--
-- Expected output:
--   first read:  first
--   second read: second

local io = require("@std/io")

local first = io.input()
print("first read:  " .. first)

local second = io.input()
print("second read: " .. second)
