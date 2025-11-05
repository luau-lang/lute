--!strict
-- @std/vectorext
-- stdlib for an extension of the built-in vector library in Luau
-- Provides additional utility functions for vector operations but does not include re-exports

local vectorext = {}

function vectorext.withx(vec: vector, x: number): vector
	return vector.create(x, vec.y, vec.z)
end

function vectorext.withy(vec: vector, y: number): vector
	return vector.create(vec.x, y, vec.z)
end

function vectorext.withz(vec: vector, z: number): vector
	return vector.create(vec.x, vec.y, z)
end

return table.freeze(vectorext)
