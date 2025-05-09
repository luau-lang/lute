local net = require("@lute/net")

local task = require("@std/task")

local pp = require("@batteries/pp")

local t = task.create(function()
	return net.request("https://en.wikipedia.org/")
end)

print(task.await(t).status)

print(pp(task.await(task.create(net.request, "https://en.wikipedia.org/")).headers))

local t1 = task.create(net.request, "https://en.wikipedia.org/")
local t2 = task.create(net.request, "https://www.google.com/")
local t3 = task.create(net.request, "https://www.bing.com/")

-- print(task.awaitAll(t1, t2, t3))

local together = true
local start = os.clock()

if together then
	task.awaitall(t1, t2, t3)
else
	task.await(t1)
	task.await(t2)
	task.await(t3)
end

print(os.clock() - start)

print(net.request("https://httpbin.org/post", {
	method = "POST",
	headers = {
		["Content-Type"] = "application/json",
	},
	body = '{"name":"lute"}',
}).body)

print("completed")
