--!strict
-- child and application are installed inside packages/app; each package,
-- including app itself, must resolve its own @shared.
local app = require("@app")
local child = require("@child")
local application = require("@application")

assert(app == "app:app-shared", "app got " .. app)
assert(child == "child:child-shared", "child got " .. child)
assert(application == "application:application-shared", "application got " .. application)
