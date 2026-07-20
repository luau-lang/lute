local HELP = [[Usage: lute toolchain

Project-local toolchain management is configured via .config.luau:

    return {
        lute = {
            toolchain = {
                lute = "1.0.1",
            },
        },
    }

Any lute you invoke will auto-download and dispatch to the resolved pinned version.
]]

print(HELP)
