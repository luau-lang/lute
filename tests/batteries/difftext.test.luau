local difftext = require("@batteries/difftext")
local test = require("@std/test")

local diff = difftext.diff
local applybychar, applybyline = difftext.applychardiff, difftext.applylinediff

-- general test assumption is that:
--  applying a diff(strA, strB) on strAa should equal strB
--  if this is not the case, our diff alg is broken

local function randomString(len: number)
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n\t"
	local result = {}
	for i = 1, len do
		local index = math.random(1, #chars)
		table.insert(result, chars:sub(index, index))
	end
	return table.concat(result)
end

test.suite("diffText", function(suite)
	suite:case("diffbychar on equal length strings", function(assert)
		local a, b = randomString(25), randomString(25)
		local diff = diff(a, b)
		assert.eq(applybychar(diff, a), b)
	end)

	suite:case("diffbychar on src shorter than destination", function(assert)
		local a, b = randomString(15), randomString(25)
		local diff = diff(a, b)
		assert.eq(applybychar(diff, a), b)
	end)

	suite:case("diffbychar on src longer than destination", function(assert)
		local a, b = randomString(25), randomString(15)
		local diff = diff(a, b)
		assert.eq(applybychar(diff, a), b)
	end)

	suite:case("diffbyline on equal length strings", function(assert)
		local a, b = randomString(25), randomString(25)
		local diff = diff(a, b, {
			byLine = true,
		})
		assert.eq(applybyline(diff, a), b)
	end)
	suite:case("diffbyline on src shorter than destination", function(assert)
		local a, b = randomString(15), randomString(25)
		local diff = diff(a, b, {
			byLine = true,
		})
		assert.eq(applybyline(diff, a), b)
	end)
	suite:case("diffbyline on src longer than destination", function(assert)
		local a, b = randomString(25), randomString(15)
		local diff = diff(a, b, {
			byLine = true,
		})
		assert.eq(applybyline(diff, a), b)
	end)
end)

test.run()
