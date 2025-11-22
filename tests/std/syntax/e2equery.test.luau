local test = require("@std/test")
local transforms = require("./e2eCases")
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

local function formattedTransform(initialPath: string, expectedPath: string, transformPath: string)
	stylua(initialPath, expectedPath)
	process.run({ lutePath, "transform", transformPath, initialPath })
	stylua(initialPath)
end

test.suite("Query and Transform e2e", function(suite)
	for k, _ in transforms do
		local transformName = k
		local transformPath = path.format(path.join(allCasesPath, transformName, "init.luau"))
		local transformCasesPath = path.format(path.join(allCasesPath, transformName, "cases"))

		assert(fs.exists(transformPath), `{transformPath} does not exist.`)

		-- for each case, in .../cases/caseN/...luau
		-- 		move intial.luau to .../cases/caseN.luau and expected.luau to .../cases/caseN.luau.expect
		-- 		output result at .../cases/caseN.luau.result
		--

		suite:case(transformName, function(assert)
			for _, v in fs.listdirectory(transformCasesPath) do
				if v.type ~= "file" then
					continue
				end

				local case = v.name
				-- print(case)
				if case == ".luaurc" or case:find(".expect") or case:find(".result") then
					continue
				end

				local casePath = path.format(path.join(transformCasesPath, case))
				local expectedPath = path.format(path.join(transformCasesPath, `{case}.expect`))
				local resultPath = path.format(path.join(transformCasesPath, `{case}.result`))

				local initialSrc = fs.readfiletostring(casePath)
				formattedTransform(casePath, expectedPath, transformPath)

				local result = fs.readfiletostring(casePath)
				fs.writestringtofile(resultPath, result)
				fs.writestringtofile(casePath, initialSrc)
				local expectedResult = fs.readfiletostring(expectedPath)

				assert.eq(result, expectedResult)
				-- output diff
			end
		end)
	end
end)

test.run()
