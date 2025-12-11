local crc32 = require("../crc")

export type CrcValidationOptions = {
	skip: boolean,
	expected: number,
}

local function validateCrc(decompressed: buffer, validation: CrcValidationOptions)
	-- Unless skipping validation is requested, we verify the checksum
	if not validation.skip then
		local computed = crc32(decompressed)
		assert(
			validation.expected == computed,
			`Validation failed; CRC checksum does not match: {string.format("%x", computed)} ~= {string.format(
				"%x",
				computed
			)} (expected ~= got)`
		)
	end
end

return validateCrc
