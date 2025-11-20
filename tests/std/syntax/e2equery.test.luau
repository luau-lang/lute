local test = require("@std/test")
local tableext = require("@std/tableext")
local transforms = require("./e2eCases")
local process = require("@lute/process")
local path = require("@std/path")
local fs = require("@std/fs")

local function stylua(...: string)
	process.run({ "stylua", ... }, {
		shell = true,
	})
end

local function safeMkDir(path: string)
	if not fs.exists(path) then
		fs.createdirectory(path)
	end
end

local lutePath = process.execpath()
local snapshotsDir = "transform_snapshots"
local casesPath = path.format(path.join(".", "tests", "std", "syntax", "e2eCases"))

local function clearSnapshots()
	if fs.exists(snapshotsDir) then
		local it = fs.walk(snapshotsDir, { recursive = true })
		local p = it()
		while p do
			local path = path.format(p)
			if fs.type(path) == "file" then
				fs.remove(path)
			end
			p = it()
		end
	end
end

clearSnapshots()
safeMkDir(snapshotsDir)

test.suite("Query and Transform e2e", function(suite)
	tableext.foreach(transforms, function(k, v)
		local transformName, _transformFunc, transformCases = k, v.transform, v.cases

		local caseDir = path.format(path.join(snapshotsDir, transformName))
		local transformPath = path.format(path.join(casesPath, transformName, "init.luau"))

		print(transformPath)
		assert(fs.exists(transformPath), `{transformPath} does not exist.`)
		safeMkDir(caseDir)

		suite:case(transformName, function(assert)
			tableext.foreach(transformCases, function(i, v)
				local subcase = `case{i}`
				local subcaseBasePath = path.format(path.join(caseDir, subcase))
				safeMkDir(subcaseBasePath)
				local initialPath = path.format(path.join(subcaseBasePath, "initial.luau"))
				local expectedPath = path.format(path.join(subcaseBasePath, "expected.luau"))
				local resultPath = path.format(path.join(subcaseBasePath, "result.luau"))

				fs.writestringtofile(initialPath, v.initial)
				fs.writestringtofile(expectedPath, v.expected)
				stylua(initialPath, expectedPath)
				local initialState = fs.readfiletostring(initialPath)
				process.run({ lutePath, "transform", transformPath, initialPath })
				stylua(initialPath, expectedPath)

				local result = fs.readfiletostring(initialPath)
				fs.writestringtofile(resultPath, result)
				fs.writestringtofile(initialPath, initialState)

				local expectedResult = fs.readfiletostring(expectedPath)

				assert.eq(result, expectedResult)
			end)
		end)
	end)
end)

test.run()
