local testutil = {}

function testutil.normalizeLineEndings(contents: string): string
	local noCrlf, _ = contents:gsub("\r+\n", "\n")
	local noCr, _ = noCrlf:gsub("\r+", "\n")
	return noCr
end

return table.freeze(testutil)
