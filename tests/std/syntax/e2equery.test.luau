local test = require("@std/test")
local difftext = require("@batteries/difftext")
local richterm = require("@batteries/richterm")
local process = require("@lute/process")
local path = require("@std/path")
local fs = require("@std/fs")
local tableext = require("@std/tableext")

local function stylua(...: string)
	process.run({ "stylua", ... }, {
		shell = true,
	})
end

local lutePath = process.execpath()

local function formattedTransform(initialPath: path.path, transformPath: string): (string, string)
	local expectedPath = path.format(initialPath) .. ".expect"
	local resultPath = path.format(initialPath) .. ".result"
	process.run({ lutePath, "transform", "--output", resultPath, transformPath, path.format(initialPath) })
	stylua(resultPath, expectedPath)
	local result = fs.readfiletostring(resultPath)
	local expectedResult = fs.readfiletostring(expectedPath)
	return expectedResult, result
end

local function getCases(casesDir: path.path)
	local cases = fs.listdirectory(path.format(casesDir))
	return tableext.filter(cases, function(case)
		return case.type == "file" and path.extname(case.name) == ".luau"
	end)
end

local transformsDir = "./tests/std/syntax/e2eCases"
test.suite("E2E Query Transforms", function(suite: any)
	local casesWalker = fs.walk(transformsDir, { recursive = true })
	local curFile = casesWalker()

	while curFile do
		if path.basename(curFile) == "init.luau" then
			local transformDir = path.dirname(curFile)
			local transformName = path.basename(transformDir)
			local transormFile = path.format(curFile)

			suite:case(transformName, function(assert)
				local casesPath = path.join(transformDir, "cases")
				local cases = getCases(casesPath)
				for _, case in cases do
					local result, expected = formattedTransform(path.join(casesPath, case.name), transormFile)

					local outputDiff = difftext.prettydiff(result, expected, {
						detailed = true,
						includeLineNumbers = true,
					})

					assert.eq(
						result,
						expected,
						`\n{richterm.bold("Transform result ~= expected result")}:\n{outputDiff}`
					)
				end
			end)
		end

		curFile = casesWalker()
	end
end)

test.run()
