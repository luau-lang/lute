local task = require("@lute/task")

task.delay(1, coroutine.create(print), vector.one)

task.delay(1, print, vector.one)
