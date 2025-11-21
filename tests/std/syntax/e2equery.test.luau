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

local function safeMkDir(path: string)
	if not fs.exists(path) then
		fs.createdirectory(path)
	end
end

local lutePath = process.execpath()
local snapshotsDir = "transform_snapshots"
local allCasesPath = path.format(path.join(".", "tests", "std", "syntax", "e2eCases"))

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

print(fs.readfiletostring("./tests/std/syntax/e2eCases/roactToReact/cases/case1/initial.luau"))

local function formattedTransform(initialPath: string, expectedPath: string, transformPath: string)
	stylua(initialPath, expectedPath)
	process.run({ lutePath, "transform", transformPath, initialPath })
	stylua(initialPath)
end

clearSnapshots()
safeMkDir(snapshotsDir)

test.suite("Query and Transform e2e", function(suite)
	for k, _ in transforms do
		local transformName = k
		local transformPath = path.format(path.join(allCasesPath, transformName, "init.luau"))
		local transformCasesPath = path.format(path.join(allCasesPath, transformName, "cases"))

		assert(fs.exists(transformPath), `{transformPath} does not exist.`)

		suite:case(transformName, function(assert)
			for i, v in fs.listdirectory(transformCasesPath) do
				if v.type ~= "dir" then
					continue
				end

				local subcase = v.name
				local subcaseBasePath = path.format(path.join(transformCasesPath, subcase))
				local initialPath = path.format(path.join(subcaseBasePath, "initial.luau"))
				local expectedPath = path.format(path.join(subcaseBasePath, "expected.luau"))
				local resultPath = path.format(path.join(subcaseBasePath, "result.luau"))

				local initialSrc = fs.readfiletostring(initialPath)

				formattedTransform(initialPath, expectedPath, transformPath)

				local result = fs.readfiletostring(initialPath)
				fs.writestringtofile(resultPath, result)
				fs.writestringtofile(initialPath, initialSrc)

				local expectedResult = fs.readfiletostring(expectedPath)

				assert.eq(result, expectedResult)
			end
		end)
	end
end)

test.run()
