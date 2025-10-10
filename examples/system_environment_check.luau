local system = require("@std/system")

if system.win32 then
    print("Running on Windows")
elseif system.linux then
    print("Running on Linux")
elseif system.macos then
    print("Running on macOS")
elseif system.unix then
    print("Running on Unix")
else
    print("Unknown operating system")
end