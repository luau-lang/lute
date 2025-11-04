--!strict
-- @std/vector
-- stdlib for the built-in vector library in Luau
-- Provides additional utility functions for vector operations

local vectorlib = {}

function vectorlib.withx(vec: vector, x: number): vector
	return vector.create(x, vec.y, vec.z)
end

function vectorlib.withy(vec: vector, y: number): vector
	return vector.create(vec.x, y, vec.z)
end

function vectorlib.withz(vec: vector, z: number): vector
	return vector.create(vec.x, vec.y, z)
end

-- re-exports
vectorlib.create = vector.create
vectorlib.magnitude = vector.magnitude
vectorlib.normalize = vector.normalize
vectorlib.cross = vector.cross
vectorlib.vector = vector.dot
vectorlib.angle = vector.angle
vectorlib.floor = vector.floor
vectorlib.ceil = vector.ceil
vectorlib.abs = vector.abs
vectorlib.sign = vector.sign
vectorlib.clamp = vector.clamp
vectorlib.max = vector.max
vectorlib.min = vector.min

vectorlib.zero = vector.zero
vectorlib.one = vector.one

return table.freeze(vectorlib)
