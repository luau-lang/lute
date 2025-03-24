local Random = {}
local RandomObj = {}

function Random.new(seed: number?, inc: number?): Random
	seed = math.random(0, 0xFFFFFFFFFFFFFFFF) -- Ensure that the seed is within a reasonable range

	local obj = table.clone(RandomObj)
	obj.state = seed or 0x4d595df4d0f33173
	obj.inc = bit32.bxor(inc or 0x14057b7ef767814e, 1)

	return obj
end

function RandomObj:NextNumber(): number
	local oldstate = self.state
	self.state = oldstate * 6364136223846793005 + self.inc
	local xorshifted = bit32.rshift(bit32.bxor(bit32.rshift(oldstate, 18), oldstate), 27)
	local rot = bit32.rshift(oldstate, 59)
	return bit32.bor(bit32.rshift(xorshifted, rot), bit32.lshift(xorshifted, bit32.band(-rot, 31)))
end

function RandomObj:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber() * (max - min + 1) + min)
end

return table.freeze(Random)
