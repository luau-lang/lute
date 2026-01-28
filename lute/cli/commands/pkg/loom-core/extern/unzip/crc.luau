local CRC32_TABLE = table.create(256)

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

	for i = 0, buffer.len(buf) - 1 do
		local byte = buffer.readu8(buf, i)
		local index = bit32.band(bit32.bxor(crc, byte), 0xFF)
		crc = bit32.bxor(bit32.rshift(crc, 8), CRC32_TABLE[index])
	end

	return bit32.bxor(crc, 0xFFFFFFFF)
end

return crc32
