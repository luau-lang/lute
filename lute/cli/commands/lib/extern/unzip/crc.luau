local CRC32_TABLE: { number } = table.create(256) :: any

-- TODO: Maybe compute this AoT as an optimization
-- Initialize the lookup table and lock it in place
for i = 0, 255 do
	local crc = i
	for _ = 1, 8 do
		if bit32.band(crc, 1) == 1 then
			crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
		else
			crc = bit32.rshift(crc, 1)
		end
	end
	CRC32_TABLE[i] = crc
end

table.freeze(CRC32_TABLE)

local function crc32(buf: buffer): number
	local crc = 0xFFFFFFFF
	local len = buffer.len(buf)
	local i = 0

	-- OPT: Unroll to process 8 bytes at a time for better performance
	while i + 7 < len do
		local b0 = buffer.readu8(buf, i)
		local b1 = buffer.readu8(buf, i + 1)
		local b2 = buffer.readu8(buf, i + 2)
		local b3 = buffer.readu8(buf, i + 3)
		local b4 = buffer.readu8(buf, i + 4)
		local b5 = buffer.readu8(buf, i + 5)
		local b6 = buffer.readu8(buf, i + 6)
		local b7 = buffer.readu8(buf, i + 7)

		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b0), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b1), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b2), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b3), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b4), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b5), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b6), 0xFF)])
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[bit32.band(bit32.bxor(crc, b7), 0xFF)])

		i += 8
	end

	-- Process remaining bytes
	while i < len do
		local byte = buffer.readu8(buf, i)
		local index = bit32.band(bit32.bxor(crc, byte), 0xFF)
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[index])
		i += 1
	end

	return bit32.bxor(crc, 0xFFFFFFFF)
end

return crc32
