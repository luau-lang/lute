-- Must not resolve to packages/outside.luau, which is outside the install root.
return require("./outside")
