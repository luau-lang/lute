-- Tree class for storing Huffman trees used in DEFLATE decompression
local Tree = {}

export type Tree = typeof(setmetatable({} :: TreeInner, { __index = Tree }))
type TreeInner = {
	table: { number }, -- Length of 16, stores code length counts
	trans: { number }, -- Length of 288, stores code to symbol translations
	lookup: { number }?, -- Precomputed Huffman lookup table for fast path
}

--- Creates a new Tree instance with initialized tables
function Tree.new(): Tree
	return setmetatable(
		{
			table = table.create(16, 0),
			trans = table.create(288, 0),
			lookup = nil,
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
    sourceLen: number,   -- Cached length of source buffer
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
			sourceLen = buffer.len(source),
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

-- Pre-calculate bitmasks for bit extraction, this only runs on the first
-- require before this module is cached
local bitMasks = table.create(17, 0)
for i = 0, 16 do
	bitMasks[i] = bit32.rshift(0xffff, 16 - i)
end

-- Maximum bit length for fixed Huffman codes. We selected 9 as a good mean
-- value instead of 10 or 12 as they seemed to be slightly slower, potentially
-- due to table memory overhead. In my testing using the `pandoc_soft_links`
-- file, I found these throughputs:
--
-- - 10-bit (1024 entries): 15.0 MB / s
-- - 12-bit (4096 entries): 11.5 MB / s
-- - 9-bit  (512 entries):  17.2 MB / s

local LOOKUP_BITS = 9
local LOOKUP_SIZE = bit32.lshift(1, LOOKUP_BITS) -- OPT: lshift instead of exponentiation

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

--- Builds a fast lookup table for the first `LOOKUP_BITS` bits of Huffman codes
local function buildLookupTable(t: Tree)
	local lookup = table.create(LOOKUP_SIZE, 0)

	for i = 0, LOOKUP_SIZE - 1 do
		-- Traverse the Huffman tree to find what this bit pattern decodes to
		local sum, cur, len = 0, 0, 0
		local bits = i

		repeat
			cur = 2 * cur + bit32.band(bits, 1)
			bits = bit32.rshift(bits, 1)
			len += 1

			-- Huffman codes cannot be longer than 15 bits
			if len > 15 then
				break
			end

			sum += t.table[len]
			cur -= t.table[len]
		until cur < 0

		if len <= LOOKUP_BITS then
			-- Only store in lookup table if it is within the bits range
			-- High 16 bits = symbol; low 16 bits = length
			local symbol = t.trans[sum + cur]
			lookup[i] = bit32.lshift(symbol, 16) + len
		else
			-- NOTE: a length of zero signifies no fast path
			lookup[i] = 0
		end
	end

	t.lookup = lookup
end

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

	-- Build fast lookup table for first LOOKUP_BITS bits
	buildLookupTable(t)
end

--- Ensures the bitbuffer has enough bits available
local function ensureBits(d: Data, minBits: number)
	if d.bitcount >= minBits then
		return
	end

	-- Refill as much as possible at once
	while d.bitcount < 24 and d.sourceIndex < d.sourceLen do
		d.tag = bit32.bor(d.tag, bit32.lshift(buffer.readu8(d.source, d.sourceIndex), d.bitcount))
		d.sourceIndex += 1
		d.bitcount += 8
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

	ensureBits(d, num)

	local val = bit32.band(d.tag, bitMasks[num])
	d.tag = bit32.rshift(d.tag, num)
	d.bitcount -= num

	return val + base
end

--- Decodes a symbol using a Huffman tree with fast lookup table
local function decodeSymbol(d: Data, t: Tree): number
	-- Longest possible code in a Huffman table is 15 bits, ensure
	-- there are enough bits for that
	ensureBits(d, 15)

	-- Fast path: lookup first `LOOKUP_BITS`
	local lookup = t.lookup :: { number }
	local lookupIndex = bit32.band(d.tag, LOOKUP_SIZE - 1)
	local entry = lookup[lookupIndex]
	local len = bit32.band(entry, 0xFFFF)

	if len > 0 then
		-- If the code fits within the `LOOKUP_BITS` size, nothing more
		-- to be done
		local symbol = bit32.rshift(entry, 16)
		d.tag = bit32.rshift(d.tag, len)
		d.bitcount -= len
		return symbol
	end

	-- Slow path: code is longer than `LOOKUP_BITS`, we need to traverse
	-- the full tree on our own
	local sum, cur = 0, 0
	local tag = d.tag
	len = 0

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
	local dest = d.dest
	local destLen = d.destLen
	local destSize = buffer.len(dest)

	local lastGrowCheck = destLen

	while true do
		-- OPT: inlined `decodeSymbol` for length tree
		ensureBits(d, 15)
		local entry = (lengthTree.lookup :: { number })[bit32.band(d.tag, LOOKUP_SIZE - 1)]
		local len = bit32.band(entry, 0xFFFF)
		local sym

		if len > 0 then
			sym = bit32.rshift(entry, 16)
			d.tag = bit32.rshift(d.tag, len)
			d.bitcount -= len
		else
			-- Slow path
			local sum, cur = 0, 0
			local tag = d.tag
			len = 0

			repeat
				cur = 2 * cur + bit32.band(tag, 1)
				tag = bit32.rshift(tag, 1)
				len += 1
				sum += lengthTree.table[len]
				cur -= lengthTree.table[len]
			until cur < 0

			d.tag = tag
			d.bitcount -= len
			sym = lengthTree.trans[sum + cur]
		end

		-- OPT: literals are the most common symbols
		if sym < 256 then
			-- Check growth periodically
			if destLen - lastGrowCheck >= 64 then
				if destLen + 64 > destSize then
					local newSize = destSize * 2
					local newDest = buffer.create(newSize)

					buffer.copy(newDest, 0, dest, 0, destLen)

					dest = newDest
					d.dest = newDest
					destSize = newSize
				end

				lastGrowCheck = destLen
			end

			buffer.writeu8(dest, destLen, sym)
			destLen += 1
		elseif sym == 256 then
			-- End of block
			d.destLen = destLen
			return
		else
			-- Length/distance pair for copying
			sym -= 257

			local length = readBits(d, lengthBits[sym], lengthBase[sym])

			-- OPT: inlined `decodeSymbol` for distance tree
			ensureBits(d, 15)
			entry = (distTree.lookup :: { number })[bit32.band(d.tag, LOOKUP_SIZE - 1)]
			len = bit32.band(entry, 0xFFFF)

			local dist

			if len > 0 then
				dist = bit32.rshift(entry, 16)
				d.tag = bit32.rshift(d.tag, len)
				d.bitcount -= len
			else
				-- Slow path
				local sum, cur = 0, 0
				local tag = d.tag
				len = 0

				repeat
					cur = 2 * cur + bit32.band(tag, 1)
					tag = bit32.rshift(tag, 1)
					len += 1
					sum += distTree.table[len]
					cur -= distTree.table[len]
				until cur < 0

				d.tag = tag
				d.bitcount -= len
				dist = distTree.trans[sum + cur]
			end

			dist = readBits(d, distBits[dist], distBase[dist])
			local offs = destLen - dist

			-- Check if we need to grow the buffer
			if destLen + length > destSize then
				local newSize = math.max(destSize * 2, destLen + length)
				local newDest = buffer.create(newSize)

				buffer.copy(newDest, 0, dest, 0, destLen)

				dest = newDest
				d.dest = newDest
				destSize = newSize
			end

			-- Validate offset is within bounds
			if offs < 0 then
				error(`Invalid distance: trying to copy from offset {offs} (destLen={destLen}, dist={dist})`)
			end

			-- OPT: Non-overlapping copies are common
			if dist >= length then
				-- We can directly memcpy
				buffer.copy(dest, destLen, dest, offs, length)
				destLen += length
			elseif length <= 8 then
				-- OPT: small overlapping copies, we can unroll upto 8 bytes manually,
				-- prepare for extremely ugly code ahead
				if length <= 4 then
					buffer.writeu8(dest, destLen, buffer.readu8(dest, offs))
					buffer.writeu8(dest, destLen + 1, buffer.readu8(dest, offs + 1))

					if length > 2 then
						buffer.writeu8(dest, destLen + 2, buffer.readu8(dest, offs + 2))
						if length > 3 then
							buffer.writeu8(dest, destLen + 3, buffer.readu8(dest, offs + 3))
						end
					end
				else
					buffer.writeu8(dest, destLen, buffer.readu8(dest, offs))
					buffer.writeu8(dest, destLen + 1, buffer.readu8(dest, offs + 1))
					buffer.writeu8(dest, destLen + 2, buffer.readu8(dest, offs + 2))
					buffer.writeu8(dest, destLen + 3, buffer.readu8(dest, offs + 3))

					if length > 4 then
						buffer.writeu8(dest, destLen + 4, buffer.readu8(dest, offs + 4))
						if length > 5 then
							buffer.writeu8(dest, destLen + 5, buffer.readu8(dest, offs + 5))
							if length > 6 then
								buffer.writeu8(dest, destLen + 6, buffer.readu8(dest, offs + 6))
								if length > 7 then
									buffer.writeu8(dest, destLen + 7, buffer.readu8(dest, offs + 7))
								end
							end
						end
					end
				end
				destLen += length
			elseif dist == 1 then
				-- OPT: single byte repition is common
				local byte = buffer.readu8(dest, offs)
				for i = 0, length - 1 do
					buffer.writeu8(dest, destLen + i, byte)
				end
				destLen += length
			else
				-- OPT: try chunked overlapping copies
				local chunkSize = dist
				local chunks = length // chunkSize
				local remainder = length % chunkSize

				for _ = 1, chunks do
					buffer.copy(dest, destLen, dest, offs, chunkSize)
					destLen += chunkSize
					offs += chunkSize
				end

				if remainder > 0 then
					for i = 0, remainder - 1 do
						buffer.writeu8(dest, destLen + i, buffer.readu8(dest, offs + i))
					end
					destLen += remainder
				end
			end

			lastGrowCheck = destLen
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

	-- Check if we need to grow the buffer
	local destSize = buffer.len(d.dest)
	if d.destLen + length > destSize then
		local newSize = math.max(destSize * 2, d.destLen + length)
		local newDest = buffer.create(newSize)

		buffer.copy(newDest, 0, d.dest, 0, d.destLen)
		d.dest = newDest
	end

	-- Use bulk copy for uncompressed data
	buffer.copy(d.dest, d.destLen, d.source, d.sourceIndex, length)
	d.destLen += length
	d.sourceIndex += length

	d.bitcount = 0
end

--- Main decompression function that processes DEFLATE compressed data
local function uncompress(source: buffer, uncompressedSize: number?): buffer
	local dest = buffer.create(
		-- If the uncompressed size is known, we use that, otherwise we use a default
		-- size that is a 7 times more than the compressed size; this factor works
		-- well for most cases other than those with a very high compression ratio
		if uncompressedSize and uncompressedSize > 0 then uncompressedSize else buffer.len(source) * 7
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
	if d.destLen < buffer.len(d.dest) then
		local result = buffer.create(d.destLen)
		buffer.copy(result, 0, d.dest, 0, d.destLen)
		return result
	end

	return d.dest
end

-- Initialize static trees and lookup tables for DEFLATE format
buildFixedTrees(staticLengthTree, staticDistTree)
buildLookupTable(staticLengthTree)
buildLookupTable(staticDistTree)
buildBitsBase(lengthBits, lengthBase, 4, 3)
buildBitsBase(distBits, distBase, 2, 1)
lengthBits[28] = 0
lengthBase[28] = 258

return uncompress
