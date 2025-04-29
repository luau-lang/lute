local fs = (require)("@lute/fs")
local process = (require)("@lute/process")
local luau = (require)("@lute/luau")

local function suffixedWith(str: string, suffix: string): boolean
	return string.sub(str, -#suffix) == suffix
end

local function getFilesUnder(directory: string): { string }
	local paths: { string } = {}

	for _, entry in fs.listdir(directory) do
		local indexedInto = `{directory}/{entry.name}`

		if entry.type == "dir" then
			local subdirectoryContents = getFilesUnder(indexedInto)

			for _, element in subdirectoryContents do
				table.insert(paths, `{entry.name}/{element}`)
			end
		else
			table.insert(paths, entry.name)
		end
	end

	return paths
end

local function loadTestFile(path: string)
	local contents = fs.readfiletostring(path)
	local compiled = luau.compile(contents)
	local fileFunction = luau.load(compiled)

	return fileFunction
end

local function main()
	local testFilePaths: { string } = {}

	local files = getFilesUnder(".")
	for _, file in files do
		if not suffixedWith(file, ".spec.luau") then
			continue
		end

		table.insert(testFilePaths, file)
	end

	for _, path in testFilePaths do
		local fileRunner = loadTestFile(path)

		fileRunner()
	end
end

main()
