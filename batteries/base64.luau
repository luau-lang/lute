--!optimize 2
--!strict

-- assume little-endian system
assert(string.pack("=i2", 1) == "\1\0", "system must be little-endian")

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_ENCODING_LUT = table.create(4096) :: { number }
local BASE64_DECODING_LUT = buffer.create(256)

do
	for i = 0, 4095 do
		local hi = bit32.rshift(i, 6) + 1
		local lo = bit32.band(i, 0x3F) + 1
		BASE64_ENCODING_LUT[i + 1] =
			bit32.bor(string.byte(BASE64_ALPHABET, hi), bit32.lshift(string.byte(BASE64_ALPHABET, lo), 8))
	end

	-- prefill lookup table with invalid base64 value (0xFF)
	buffer.fill(BASE64_DECODING_LUT, 0, 0xFF)
	for i = 1, #BASE64_ALPHABET do
		buffer.writeu8(BASE64_DECODING_LUT, string.byte(BASE64_ALPHABET, i), i - 1)
	end
end

@native
local function encode(input_buffer: buffer): buffer
	assert(typeof(input_buffer) == "buffer", "Expected input to be a buffer")

	local input_length = buffer.len(input_buffer)

	if input_length == 0 then
		return buffer.create(0)
	end

	local output = buffer.create(((input_length + 2) // 3) * 4)
	local output_idx = 0
	local i = 0

	while i + 3 <= input_length do
		local triple = bit32.bor(
			bit32.lshift(buffer.readu8(input_buffer, i), 16),
			bit32.lshift(buffer.readu8(input_buffer, i + 1), 8),
			buffer.readu8(input_buffer, i + 2)
		)

		local high = bit32.band(bit32.rshift(triple, 12), 0xFFF) + 1
		local low = bit32.band(triple, 0xFFF) + 1

		local pair0 = BASE64_ENCODING_LUT[high]
		local pair1 = BASE64_ENCODING_LUT[low]

		buffer.writeu32(output, output_idx, bit32.bor(pair0, bit32.lshift(pair1, 16)))

		i += 3
		output_idx += 4
	end

	local rem = input_length - i

	if rem == 1 then
		local high = bit32.band(bit32.lshift(buffer.readu8(input_buffer, i), 4), 0xFF0)

		local TWO_EQUALS = 0x3D3D
		buffer.writeu32(output, output_idx, bit32.bor(BASE64_ENCODING_LUT[high + 1], bit32.lshift(TWO_EQUALS, 16)))
	elseif rem == 2 then
		local first = buffer.readu8(input_buffer, i)
		local second = buffer.readu8(input_buffer, i + 1)
		local high = bit32.bor(bit32.lshift(first, 4), bit32.rshift(second, 4))
		local low_idx = bit32.lshift(bit32.band(second, 0x0F), 2)
		local low_equals = bit32.bor(string.byte(BASE64_ALPHABET, low_idx + 1), bit32.lshift(0x3D, 8))

		buffer.writeu32(output, output_idx, bit32.bor(BASE64_ENCODING_LUT[high + 1], bit32.lshift(low_equals, 16)))
	end

	return output
end

@native
local function decode(input_buffer: buffer): buffer
	assert(typeof(input_buffer) == "buffer", "Expected input to be a buffer")

	local input_length = buffer.len(input_buffer)

	if input_length == 0 then
		return buffer.create(0)
	end

	-- strip padding (rfc-4648 section 3.3: the excess pad characters MAY also be ignored)
	while input_length > 0 and buffer.readu8(input_buffer, input_length - 1) == 0x3D do
		input_length -= 1
	end

	-- rfc-4648 section 3.3 forbids padding that isn't preceded by at least one Base64 digit
	if input_length == 0 then
		error("Invalid base64 input", 2)
	end

	-- get correct output size
	local output_length = (3 * input_length) // 4
	local output = buffer.create(output_length)

	local read_offset = 0
	local write_offset = 0
	-- loop invariant: at least 4 bytes to write
	while write_offset + 4 <= output_length do
		local b4 = buffer.readu8(BASE64_DECODING_LUT, buffer.readu8(input_buffer, read_offset + 3))
		local b3 = buffer.readu8(BASE64_DECODING_LUT, buffer.readu8(input_buffer, read_offset + 2))
		local b2 = buffer.readu8(BASE64_DECODING_LUT, buffer.readu8(input_buffer, read_offset + 1))
		local b1 = buffer.readu8(BASE64_DECODING_LUT, buffer.readu8(input_buffer, read_offset))
		if bit32.bor(b1, b2, b3, b4) >= 64 then
			error("Invalid base64 input", 2)
		end
		read_offset += 4
		-- u32 BE: [B1, B2, B3, 0] = b1<<26|b2<<20|b3<<14|b4<<8, trailing 0 will be overwritten next iteration
		buffer.writeu32(output, write_offset, bit32.byteswap(b1 * 0x4000000 + b2 * 0x100000 + b3 * 0x4000 + b4 * 0x100))
		write_offset += 3
	end

	local u24be, nbits = 0, 0
	while read_offset < input_length do
		local b = buffer.readu8(BASE64_DECODING_LUT, buffer.readu8(input_buffer, read_offset))
		read_offset += 1
		if b >= 64 then
			error("Invalid base64 input", 2)
		end
		u24be = u24be * 0x40 + b
		nbits += 6
	end
	while nbits >= 8 do
		buffer.writeu8(output, write_offset, bit32.rshift(u24be, nbits - 8))
		nbits -= 8
		write_offset += 1
	end
	-- 2 or 4 leftover bits must be zero
	if nbits == 6 or (nbits == 2 and bit32.btest(u24be, 0x03)) or (nbits == 4 and bit32.btest(u24be, 0x0F)) then
		error("Invalid base64 input", 2)
	end
	return output
end

return table.freeze({
	encode = encode,
	decode = decode,
})
