-- Tree class for storing Huffman trees used in DEFLATE decompression
local Tree = {}

export type Tree = typeof(setmetatable({} :: TreeInner, { __index = Tree }))
type TreeInner = {
	table: { number }, -- Length of 16, stores code length counts
	trans: { number }, -- Length of 288, stores code to symbol translations
}

--- Creates a new Tree instance with initialized tables
function Tree.new(): Tree
	return setmetatable(
		{
			table = table.create(16, 0),
			trans = table.create(288, 0),
		} :: TreeInner,
		{ __index = Tree }
	)
end

-- Data class for managing compression state and buffers
local Data = {}
export type Data = typeof(setmetatable({} :: DataInner, { __index = Data }))
-- stylua: ignore
export type DataInner = {
    source: buffer,      -- Input buffer containing compressed data
    sourceIndex: number, -- Current position in source buffer
    tag: number,         -- Bit buffer for reading compressed data
    bitcount: number,    -- Number of valid bits in tag

    dest: buffer,       -- Output buffer for decompressed data
    destLen: number,    -- Current length of decompressed data

    ltree: Tree,        -- Length/literal tree for current block
    dtree: Tree,        -- Distance tree for current block
}

--- Creates a new Data instance with initialized compression state
function Data.new(source: buffer, dest: buffer): Data
	return setmetatable(
		{
			source = source,
			sourceIndex = 0,
			tag = 0,
			bitcount = 0,
			dest = dest,
			destLen = 0,
			ltree = Tree.new(),
			dtree = Tree.new(),
		} :: DataInner,
		{ __index = Data }
	)
end

-- Static Huffman trees used for fixed block types
local staticLengthTree = Tree.new()
local staticDistTree = Tree.new()

-- Tables for storing extra bits and base values for length/distance codes
local lengthBits = table.create(30, 0)
local lengthBase = table.create(30, 0)
local distBits = table.create(30, 0)
local distBase = table.create(30, 0)

-- Special ordering of code length codes used in dynamic Huffman trees
-- stylua: ignore
local clcIndex = {
    16, 17, 18, 0, 8, 7, 9, 6,
    10, 5, 11, 4, 12, 3, 13, 2,
    14, 1, 15
}

-- Tree used for decoding code lengths in dynamic blocks
local codeTree = Tree.new()
local lengths = table.create(288 + 32, 0)

--- Builds the extra bits and base tables for length and distance codes
local function buildBitsBase(bits: { number }, base: { number }, delta: number, first: number)
	local sum = first

	-- Initialize the bits table with appropriate bit lengths
	for i = 0, delta - 1 do
		bits[i] = 0
	end
	for i = 0, 29 - delta do
		bits[i + delta] = math.floor(i / delta)
	end

	-- Build the base value table using bit lengths
	for i = 0, 29 do
		base[i] = sum
		sum += bit32.lshift(1, bits[i])
	end
end

--- Constructs the fixed Huffman trees used in DEFLATE format
local function buildFixedTrees(lengthTree: Tree, distTree: Tree)
	-- Build the fixed length tree according to DEFLATE specification
	for i = 0, 6 do
		lengthTree.table[i] = 0
	end
	lengthTree.table[7] = 24
	lengthTree.table[8] = 152
	lengthTree.table[9] = 112

	-- Populate the translation table for length codes
	for i = 0, 23 do
		lengthTree.trans[i] = 256 + i
	end
	for i = 0, 143 do
		lengthTree.trans[24 + i] = i
	end
	for i = 0, 7 do
		lengthTree.trans[24 + 144 + i] = 280 + i
	end
	for i = 0, 111 do
		lengthTree.trans[24 + 144 + 8 + i] = 144 + i
	end

	-- Build the fixed distance tree (simpler than length tree)
	for i = 0, 4 do
		distTree.table[i] = 0
	end
	distTree.table[5] = 32

	for i = 0, 31 do
		distTree.trans[i] = i
	end
end

--- Temporary array for building trees
local offs = table.create(16, 0)

--- Builds a Huffman tree from a list of code lengths
local function buildTree(t: Tree, lengths: { number }, off: number, num: number)
	-- Initialize the code length count table
	for i = 0, 15 do
		t.table[i] = 0
	end

	-- Count the frequency of each code length
	for i = 0, num - 1 do
		t.table[lengths[off + i]] += 1
	end

	t.table[0] = 0

	-- Calculate offsets for distribution sort
	local sum = 0
	for i = 0, 15 do
		offs[i] = sum
		sum += t.table[i]
	end

	-- Create the translation table mapping codes to symbols
	for i = 0, num - 1 do
		local len = lengths[off + i]
		if len > 0 then
			t.trans[offs[len]] = i
			offs[len] += 1
		end
	end
end

--- Reads a single bit from the input stream
local function getBit(d: Data): number
	if d.bitcount <= 0 then
		d.tag = buffer.readu8(d.source, d.sourceIndex)
		d.sourceIndex += 1
		d.bitcount = 8
	end

	local bit = bit32.band(d.tag, 1)
	d.tag = bit32.rshift(d.tag, 1)
	d.bitcount -= 1

	return bit
end

--- Reads multiple bits from the input stream with a base value
local function readBits(d: Data, num: number?, base: number): number
	if not num then
		return base
	end

	-- Ensure we have enough bits in the buffer
	while d.bitcount < 24 and d.sourceIndex < buffer.len(d.source) do
		d.tag = bit32.bor(d.tag, bit32.lshift(buffer.readu8(d.source, d.sourceIndex), d.bitcount))
		d.sourceIndex += 1
		d.bitcount += 8
	end

	local val = bit32.band(d.tag, bit32.rshift(0xffff, 16 - num))
	d.tag = bit32.rshift(d.tag, num)
	d.bitcount -= num

	return val + base
end

--- Decodes a symbol using a Huffman tree
local function decodeSymbol(d: Data, t: Tree): number
	while d.bitcount < 24 and d.sourceIndex < buffer.len(d.source) do
		d.tag = bit32.bor(d.tag, bit32.lshift(buffer.readu8(d.source, d.sourceIndex), d.bitcount))
		d.sourceIndex += 1
		d.bitcount += 8
	end

	local sum, cur, len = 0, 0, 0
	local tag = d.tag

	-- Traverse the Huffman tree to find the symbol
	repeat
		cur = 2 * cur + bit32.band(tag, 1)
		tag = bit32.rshift(tag, 1)
		len += 1
		sum += t.table[len]
		cur -= t.table[len]
	until cur < 0

	d.tag = tag
	d.bitcount -= len

	return t.trans[sum + cur]
end

--- Decodes the dynamic Huffman trees for a block
local function decodeTrees(d: Data, lengthTree: Tree, distTree: Tree)
	local hlit = readBits(d, 5, 257) -- Number of literal/length codes
	local hdist = readBits(d, 5, 1) -- Number of distance codes
	local hclen = readBits(d, 4, 4) -- Number of code length codes

	-- Initialize code lengths array
	for i = 0, 18 do
		lengths[i] = 0
	end

	-- Read code lengths for the code length alphabet
	for i = 0, hclen - 1 do
		lengths[clcIndex[i + 1]] = readBits(d, 3, 0)
	end

	-- Build the code lengths tree
	buildTree(codeTree, lengths, 0, 19)

	-- Decode length/distance tree code lengths
	local num = 0
	while num < hlit + hdist do
		local sym = decodeSymbol(d, codeTree)

		if sym == 16 then
			-- Copy previous code length 3-6 times
			local prev = lengths[num - 1]
			for _ = 1, readBits(d, 2, 3) do
				lengths[num] = prev
				num += 1
			end
		elseif sym == 17 then
			-- Repeat zero 3-10 times
			for _ = 1, readBits(d, 3, 3) do
				lengths[num] = 0
				num += 1
			end
		elseif sym == 18 then
			-- Repeat zero 11-138 times
			for _ = 1, readBits(d, 7, 11) do
				lengths[num] = 0
				num += 1
			end
		else
			-- Regular code length 0-15
			lengths[num] = sym
			num += 1
		end
	end

	-- Build the literal/length and distance trees
	buildTree(lengthTree, lengths, 0, hlit)
	buildTree(distTree, lengths, hlit, hdist)
end

--- Inflates a block of data using Huffman trees
local function inflateBlockData(d: Data, lengthTree: Tree, distTree: Tree)
	while true do
		local sym = decodeSymbol(d, lengthTree)

		if sym == 256 then
			-- End of block
			return
		end

		if sym < 256 then
			-- Literal byte
			buffer.writeu8(d.dest, d.destLen, sym)
			d.destLen += 1
		else
			-- Length/distance pair for copying
			sym -= 257

			local length = readBits(d, lengthBits[sym], lengthBase[sym])
			local dist = decodeSymbol(d, distTree)

			local offs = d.destLen - readBits(d, distBits[dist], distBase[dist])

			-- Copy bytes from back reference
			for i = offs, offs + length - 1 do
				buffer.writeu8(d.dest, d.destLen, buffer.readu8(d.dest, i))
				d.destLen += 1
			end
		end
	end
end

--- Processes an uncompressed block
local function inflateUncompressedBlock(d: Data)
	-- Align to byte boundary
	local bytesToMove = d.bitcount // 8
	d.sourceIndex -= bytesToMove
	d.bitcount = 0
	d.tag = 0

	-- Read block length and its complement
	local length = buffer.readu8(d.source, d.sourceIndex + 1)
	length = 256 * length + buffer.readu8(d.source, d.sourceIndex)

	local invlength = buffer.readu8(d.source, d.sourceIndex + 3)
	invlength = 256 * invlength + buffer.readu8(d.source, d.sourceIndex + 2)

	-- Verify block length using ones complement
	if length ~= bit32.bxor(invlength, 0xffff) then
		error("Invalid block length")
	end

	d.sourceIndex += 4

	-- Copy uncompressed data to output
	for _ = 1, length do
		buffer.writeu8(d.dest, d.destLen, buffer.readu8(d.source, d.sourceIndex))
		d.destLen += 1
		d.sourceIndex += 1
	end

	d.bitcount = 0
end

--- Main decompression function that processes DEFLATE compressed data
local function uncompress(source: buffer, uncompressedSize: number?): buffer
	local dest = buffer.create(
		-- If the uncompressed size is known, we use that, otherwise we use a default
		-- size that is a 7 times more than the compressed size; this factor works
		-- well for most cases other than those with a very high compression ratio
		uncompressedSize or buffer.len(source) * 7
	)
	local d = Data.new(source, dest)

	repeat
		local bfinal = getBit(d) -- Last block flag
		local btype = readBits(d, 2, 0) -- Block type (0=uncompressed, 1=fixed, 2=dynamic)

		if btype == 0 then
			inflateUncompressedBlock(d)
		elseif btype == 1 then
			inflateBlockData(d, staticLengthTree, staticDistTree)
		elseif btype == 2 then
			decodeTrees(d, d.ltree, d.dtree)
			inflateBlockData(d, d.ltree, d.dtree)
		else
			error("Invalid block type")
		end
	until bfinal == 1

	-- Trim output buffer to actual size if needed
	if d.destLen < buffer.len(dest) then
		local result = buffer.create(d.destLen)
		buffer.copy(result, 0, dest, 0, d.destLen)
		return result
	end

	return dest
end

-- Initialize static trees and lookup tables for DEFLATE format
buildFixedTrees(staticLengthTree, staticDistTree)
buildBitsBase(lengthBits, lengthBase, 4, 3)
buildBitsBase(distBits, distBase, 2, 1)
lengthBits[28] = 0
lengthBase[28] = 258

return uncompress
