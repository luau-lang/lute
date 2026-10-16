export type ParsedRegistryUrl = {
	read protocol: string,
	read host: string,
}

local function normalize(registryUrl: string): string
	local normalized, _ = string.gsub(registryUrl, "/+$", "")
	return normalized
end

local function parse(registryUrl: string): ParsedRegistryUrl
	local protocol, host = registryUrl:match("^(https?)://([^/]+)")
	assert(protocol ~= nil and host ~= nil, `Could not parse registry URL: {registryUrl}`)

	return table.freeze({
		protocol = protocol,
		host = host,
	})
end

local function equals(left: string?, right: string?): boolean
	if left == nil or right == nil then
		return left == right
	end

	return normalize(left) == normalize(right)
end

return {
	equals = equals,
	normalize = normalize,
	parse = parse,
}
