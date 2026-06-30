-- lute-lint-global-ignore(unused_variable)
@[native]
local function foo() end

@[deprecated({ reason = "use bar instead" })]
function bar() end

@[native, deprecated({ reason = "old" })]
local function baz() end

@native @[deprecated({ reason = "old" })]
function qux() end

local x = @[native] function() end
