--!strict
-- @std/io
-- stdlib for `@lute/io`
-- Provides standard input / output

local io = require("@lute/io")

function input(prompt: string?): string
    if prompt then
        -- Temporarily use `print` for prompt until we have proper stdout support
        print(prompt)
    end
    return io.input()
end

return table.freeze({
    input = input,
})