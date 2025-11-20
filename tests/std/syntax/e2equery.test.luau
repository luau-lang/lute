local test = require("@std/test")
local transforms = require("./e2eCases")
local process = require("@lute/process")
local path = require("@std/path")
local fs = require("@std/fs")
local system = require("@std/system")

local function styluaStr(s: string): string
	local tmp = system.tmpdir()
	local tmpFile = path.format(path.join(tmp, "to_stylua.luau"))
	fs.writestringtofile(tmpFile, s)
	process.run({ "stylua", tmpFile }, {
		shell = true,
	})
	return fs.readfiletostring(tmpFile)
end

local function styluaTxtFiles(...: string)
	local paths = table.pack(...)
	for _, path in paths do
		if typeof(path) == "string" then
			local fileContent = fs.readfiletostring(path)
			local formattedContent = styluaStr(fileContent)
			fs.writestringtofile(path, formattedContent)
		end
	end
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

local function formattedTransform(initialPath: string, expectedPath: string, transformPath: string)
	styluaTxtFiles(initialPath, expectedPath)
	process.run({ lutePath, "transform", transformPath, initialPath })
	styluaTxtFiles(initialPath)
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
				local subcase = `case{i}`
				local subcaseBasePath = path.format(path.join(transformCasesPath, subcase))
				local initialPath = path.format(path.join(subcaseBasePath, "initial.txt"))
				local expectedPath = path.format(path.join(subcaseBasePath, "expected.txt"))
				local resultPath = path.format(path.join(subcaseBasePath, "result.txt"))

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
