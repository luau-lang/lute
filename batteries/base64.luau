--!native
--!optimize 2
--!strict

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_ENCODING_LUT = table.create(4096)
local BASE64_DECODING_LUT = table.create(255, 0)

do
	for i = 0, 4095 do
		local hi = bit32.rshift(i, 6) + 1
		local lo = bit32.band(i, 0x3F) + 1
		BASE64_ENCODING_LUT[i + 1] =
			bit32.bor(string.byte(BASE64_ALPHABET, hi), bit32.lshift(string.byte(BASE64_ALPHABET, lo), 8))
	end

	for i = 1, #BASE64_ALPHABET do
		BASE64_DECODING_LUT[string.byte(BASE64_ALPHABET, i)] = i - 1
	end
end

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

local function decode(input_buffer: buffer): buffer
	assert(typeof(input_buffer) == "buffer", "Expected input to be a buffer")

	local input_length = buffer.len(input_buffer)

	if input_length == 0 then
		return buffer.create(0)
	end

	local padding_size = 0
	if input_length >= 2 and buffer.readu16(input_buffer, input_length - 2) == 0x3D3D then
		padding_size = 2
	elseif input_length >= 1 and buffer.readu8(input_buffer, input_length - 1) == 0x3D then
		padding_size = 1
	end

	-- get correct output size
	local output_length = ((input_length / 4) * 3) - padding_size
	local output = buffer.create(output_length)
	local chunks = input_length // 4

	for chunk_idx = 1, chunks do
		local index = (chunk_idx - 1) * 4
		local out_index = (chunk_idx - 1) * 3

		local value1 = BASE64_DECODING_LUT[buffer.readu8(input_buffer, index)]
		local value2 = BASE64_DECODING_LUT[buffer.readu8(input_buffer, index + 1)]
		local value3 = BASE64_DECODING_LUT[buffer.readu8(input_buffer, index + 2)]
		local value4 = BASE64_DECODING_LUT[buffer.readu8(input_buffer, index + 3)]

		local chunk = bit32.bor(bit32.lshift(value1, 18), bit32.lshift(value2, 12), bit32.lshift(value3, 6), value4)

		local character1 = bit32.rshift(chunk, 16)
		local character2 = bit32.band(bit32.rshift(chunk, 8), 0b11111111)
		local character3 = bit32.band(chunk, 0b11111111)

		-- always write the first byte
		if out_index < output_length then
			buffer.writeu8(output, out_index, character1)
		end

		-- write second byte if have space (+padding)
		if out_index + 1 < output_length then
			buffer.writeu8(output, out_index + 1, character2)
		end

		-- Write third byte if we have space (+padding)
		if out_index + 2 < output_length then
			buffer.writeu8(output, out_index + 2, character3)
		end
	end

	return output
end

return table.freeze({
	encode = encode,
	decode = decode,
})
