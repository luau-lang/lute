--!strict
--@std/test/types
-- Environment to store discovered tests

local types = require("./types")
type TestEnvironment = types.TestEnvironment

local env: TestEnvironment = { anonymous = {}, suites = {}, suiteindex = {}, caseindex = {} }

-- not frozen, the internal test library needs to mutate this during test discovery
return env
