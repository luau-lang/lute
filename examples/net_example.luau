local net = require("@std/net")

local task = require("@std/task")

local pp = require("@batteries/pp")

print(net.request("https://en.wikipedia.org/").status)

print(pp(net.request("https://en.wikipedia.org/").headers))

local start = os.clock()

local results = {}
local done = 0

task.spawn(function()
	results[1] = net.request("https://en.wikipedia.org/")
	done += 1
end)
task.spawn(function()
	results[2] = net.request("https://www.google.com/")
	done += 1
end)
task.spawn(function()
	results[3] = net.request("https://www.bing.com/")
	done += 1
end)

while done < 3 do
	task.wait()
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
