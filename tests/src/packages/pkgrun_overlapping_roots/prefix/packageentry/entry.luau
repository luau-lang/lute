--!strict
-- packages/foo and packages/app are raw string prefixes of packages/foobar and
-- packages/application; each package must resolve its own @shared.
local foo = require("@foo")
local foobar = require("@foobar")
local app = require("@app")
local application = require("@application")

assert(foo == "foo:foo-shared", "foo got " .. foo)
assert(foobar == "foobar:foobar-shared", "foobar got " .. foobar)
assert(app == "app:app-shared", "app got " .. app)
assert(application == "application:application-shared", "application got " .. application)
