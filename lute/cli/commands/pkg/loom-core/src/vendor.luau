local fs = require("@std/fs")
local lockfile = require("./lockfile")
local manifest = require("./manifest")
local path = require("@std/path")
local publishArtifact = require("./publishartifact")
local store = require("./store")

local VENDOR_DIRECTORY = ".lpm"
local PACKAGE_MANIFEST = "pkg.luau"

type VendorFile = {
	source: path.Path,
	parts: { string },
}

type VendorEntry = {
	directoryName: string,
	files: { VendorFile },
}

export type VendorResult = {
	packageCount: number,
	pathPackageCount: number,
	directory: string,
}

-- Lock keys become directory names. Everything other than letters, digits,
-- -, _, ., and @ is percent-encoded so that revisions such as feature/x stay
-- one directory and distinct keys give distinct names.
local function encodeKey(key: string): string
	assert(#key > 0, "Cannot vendor package with an empty lock key")
	local encoded = string.gsub(key, "[^%w%-_%.@]", function(character: string): string
		return string.format("%%%02X", string.byte(character))
	end)
	assert(encoded ~= "." and encoded ~= "..", `Cannot vendor package with lock key '{key}'`)
	return encoded
end

local function splitName(name: string): { string }
	return string.split(name, "/")
end

local function sortedKeys<T>(map: { [string]: T }): { string }
	local keys: { string } = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- Registry archives were filtered when they were published, so their store
-- entries are copied whole.
local function collectWholeDirectory(directory: path.Path, parts: { string }, files: { VendorFile })
	local children = fs.listDirectory(directory)
	table.sort(children, function(a: fs.DirectoryEntry, b: fs.DirectoryEntry)
		return a.name < b.name
	end)

	for _, child in children do
		local childPath = path.join(directory, child.name)
		local childParts = table.clone(parts)
		table.insert(childParts, child.name)
		if child.type == "dir" then
			collectWholeDirectory(childPath, childParts, files)
		elseif child.type == "file" then
			table.insert(files, { source = childPath, parts = childParts })
		else
			error(`Cannot vendor '{path.format(childPath)}': symlinks are not supported`)
		end
	end
end

-- GitHub packages are filtered as when publishing: only the files under
-- content_root that files selects, with content_root at the top.
local function collectFilteredPackage(packageDirectory: string): { VendorFile }
	local manifestPath = path.format(path.join(packageDirectory, PACKAGE_MANIFEST))
	assert(fs.exists(manifestPath), `Cannot vendor package: manifest not found: {manifestPath}`)
	local package = manifest.parseFile(manifestPath).package

	local files: { VendorFile } = {}
	for _, file in
		publishArtifact.collect(packageDirectory, manifestPath, {
			contentRoot = package.contentRoot,
			files = package.files,
		})
	do
		table.insert(files, { source = file.path, parts = splitName(file.name) })
	end
	return files
end

local function collectEntry(key: string, pkg: lockfile.LockfileDependency): VendorEntry
	local files: { VendorFile } = {}
	if pkg.sourceKind == "registry" then
		local registryUrl = assert(pkg.registry, `No registry URL for package '{pkg.name}'`)
		local storeKey = store.qualifyRegistryKey(key, registryUrl)
		assert(store.hasPackage(storeKey), `Cannot vendor '{key}': package is not installed in the store`)
		collectWholeDirectory(path.parse(store.getPackagePath(storeKey)), {}, files)
	elseif pkg.sourceKind == "github" then
		local rev = assert(pkg.rev, `No GitHub revision for package '{pkg.name}'`)
		local checkoutKey = store.getGitHubCheckoutKey(pkg.source, rev)
		assert(store.hasPackage(checkoutKey), `Cannot vendor '{key}': package is not installed in the store`)
		local checkoutDirectory = store.getPackagePath(checkoutKey)
		local packageDirectory = if pkg.target
			then path.format(path.resolve(checkoutDirectory, pkg.target))
			else checkoutDirectory
		files = collectFilteredPackage(packageDirectory)
	else
		error(`Cannot vendor unsupported source kind '{pkg.sourceKind}' for package '{key}'`)
	end

	return {
		directoryName = encodeKey(key),
		files = files,
	}
end

local function partsKey(parts: { string }): string
	return table.concat(parts, "/")
end

-- Copies only files whose contents changed, so tools watching the vendor
-- directory, such as rojo serve, see only real edits.
local function syncFile(source: path.Path, destination: path.Path)
	local contents = fs.readFileToString(source)
	if fs.exists(destination) then
		if fs.type(destination) == "file" and fs.readFileToString(destination) == contents then
			return
		end
		if fs.type(destination) == "dir" then
			fs.removeDirectory(destination, { recursive = true })
		else
			fs.remove(destination)
		end
	end
	fs.writeStringToFile(destination, contents)
end

local function pruneDirectory(directory: path.Path, parts: { string }, selected: { [string]: boolean }): boolean
	local empty = true
	for _, child in fs.listDirectory(directory) do
		local childPath = path.join(directory, child.name)
		local childParts = table.clone(parts)
		table.insert(childParts, child.name)
		if child.type == "dir" then
			if pruneDirectory(childPath, childParts, selected) then
				fs.removeDirectory(childPath)
			else
				empty = false
			end
		elseif selected[partsKey(childParts)] then
			empty = false
		else
			fs.remove(childPath)
		end
	end
	return empty
end

local function syncEntry(vendorDirectory: path.Path, entry: VendorEntry)
	local entryDirectory = path.join(vendorDirectory, entry.directoryName)
	if fs.exists(entryDirectory) and fs.type(entryDirectory) ~= "dir" then
		fs.remove(entryDirectory)
	end
	fs.createDirectory(entryDirectory, { makeParents = true })

	local selected: { [string]: boolean } = {}
	for _, file in entry.files do
		selected[partsKey(file.parts)] = true
	end

	for _, file in entry.files do
		local destination = path.join(entryDirectory, table.unpack(file.parts))
		fs.createDirectory(path.dirname(destination), { makeParents = true })
		syncFile(file.source, destination)
	end
	pruneDirectory(entryDirectory, {}, selected)
end

local function getVendorDirectory(rootDirectory: string): path.Path
	return path.join(rootDirectory, VENDOR_DIRECTORY)
end

-- Path packages are not copied because they already live on disk, and only
-- the project knows where to mount them in the DataModel.
local function vendor(rootDirectory: string, lock: lockfile.Lockfile, includeDev: boolean): VendorResult
	local vendorDirectory = getVendorDirectory(rootDirectory)
	local reachable = lockfile.getReachablePackageKeys(lock, includeDev)

	-- Collect every entry before touching .lpm so source/manifest errors cannot
	-- leave an existing vendor tree partially pruned.
	local entries: { VendorEntry } = {}
	local directoryNames: { [string]: boolean } = {}
	local pathPackageCount = 0
	for _, key in sortedKeys(lock.packages) do
		if not reachable[key] then
			continue
		end
		local pkg = lock.packages[key]
		if pkg.sourceKind == "path" then
			pathPackageCount += 1
			continue
		end
		local entry = collectEntry(key, pkg)
		assert(not directoryNames[entry.directoryName], `Vendor directory collision for lock key '{key}'`)
		directoryNames[entry.directoryName] = true
		table.insert(entries, entry)
	end

	if fs.exists(vendorDirectory) and fs.type(vendorDirectory) ~= "dir" then
		error(`Cannot vendor packages: {path.format(vendorDirectory)} is not a directory`)
	end
	fs.createDirectory(vendorDirectory, { makeParents = true })

	for _, entry in entries do
		syncEntry(vendorDirectory, entry)
	end

	-- Prune only after all selected entries have synchronized, so a failed copy
	-- cannot remove unrelated entries from an otherwise usable vendor tree.
	local selectedEntries: { [string]: boolean } = {}
	for _, entry in entries do
		selectedEntries[entry.directoryName] = true
	end
	for _, child in fs.listDirectory(vendorDirectory) do
		if selectedEntries[child.name] then
			continue
		end
		local childPath = path.join(vendorDirectory, child.name)
		if child.type == "dir" then
			fs.removeDirectory(childPath, { recursive = true })
		else
			fs.remove(childPath)
		end
	end

	return {
		packageCount = #entries,
		pathPackageCount = pathPackageCount,
		directory = path.format(vendorDirectory),
	}
end

return table.freeze({
	encodeKey = encodeKey,
	vendor = vendor,
	VENDOR_DIRECTORY = VENDOR_DIRECTORY,
})
