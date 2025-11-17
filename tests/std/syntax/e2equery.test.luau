local parser = require("@std/syntax/parser")
local types = require("./e2eCases/types")
local test = require("@std/test")
local table = require("@std/tableext")
local transforms = require("./e2eCases") :: { [string]: types.e2e }
local process = require("@lute/process")
local system = require("@lute/system")
local path = require("@std/path")
local fs = require("@lute/fs")

local function styluaSrc(src: string): string
	local tmpdir = system.tmpdir()

	local file = path.format(path.join(tmpdir, "to_stylua.lua"))
	local a = fs.open(file, "w+")
	fs.write(a, src)
	fs.close(a)
	process.run({ "stylua", `{tmpdir}/to_stylua.lua` }, {
		shell = true,
	})
	return fs.readfiletostring(file)
end

function trimLeadingTrailingWhitespace(src: string): string
	return src:gsub("^%s+", ""):gsub("%s+$", "")
end

local function format(s: string): string
	return trimLeadingTrailingWhitespace(styluaSrc(s))
end

test.suite("Query and Transform e2e", function(suite)
	table.foreach(transforms, function(k, v)
		local transformName, transformFunc, transformCases = k, v.transform, v.cases

		suite:case(transformName, function(assert)
			table.foreach(transformCases, function(_, v)
				local initAst = parser.parse(v.initial).root
				assert.eq(format(transformFunc(initAst)), format(v.expected))
			end)
		end)
	end)
end)

test.run()
