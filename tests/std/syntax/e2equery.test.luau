local test = require("@std/test")
local transforms = require("./e2eCases")
local difftext = require("@batteries/difftext")
local richterm = require("@batteries/richterm")
local process = require("@lute/process")
local path = require("@std/path")
local fs = require("@std/fs")

local function stylua(...: string)
	process.run({ "stylua", ... }, {
		shell = true,
	})
end

local lutePath = process.execpath()

local allCasesPath = path.format(path.join(".", "tests", "std", "syntax", "e2eCases"))

local function formattedTransform(initialPath: string, expectedPath: string, transformPath: string, resultPath: string)
	process.run({ lutePath, "transform", "--output", resultPath, transformPath, initialPath })
	stylua(resultPath, expectedPath)
end

test.suite("Query and Transform e2e", function(suite)
	for k, _ in transforms do
		local transformName = k
		local transformPath = path.format(path.join(allCasesPath, transformName, "init.luau"))
		local transformCasesPath = path.format(path.join(allCasesPath, transformName, "cases"))

		assert(fs.exists(transformPath), `{transformPath} does not exist.`)

		suite:case(transformName, function(assert)
			for _, v in fs.listdirectory(transformCasesPath) do
				if v.type ~= "file" then
					continue
				end

				local case = v.name
				if case == ".luaurc" or case:find(".expect") or case:find(".result") then
					continue
				end

				local casePath = path.format(path.join(transformCasesPath, case))
				local expectedPath = path.format(path.join(transformCasesPath, `{case}.expect`))
				local resultPath = path.format(path.join(transformCasesPath, `{case}.result`))

				formattedTransform(casePath, expectedPath, transformPath, resultPath)

				local result = fs.readfiletostring(resultPath)
				local expectedResult = fs.readfiletostring(expectedPath)

				local outputDiff = difftext.prettydiff(expectedResult, result, {
					detailed = true,
				})
				assert.eq(
					result,
					expectedResult,
					`\n{richterm.bold("Transform result ~= expected result")}:\n{outputDiff}`
				)
			end
		end)
	end
end)

test.run()
