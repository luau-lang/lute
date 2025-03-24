local function withx(vec: vector, x: number): vector
	return vector.create(x, vec.y, vec.z)
end

local function withy(vec: vector, y: number): vector
	return vector.create(vec.x, y, vec.z)
end

local function withz(vec: vector, z: number): vector
	return vector.create(vec.x, vec.y, z)
end

local function rotate(vector, angle, axis)
	local cos_angle = math.cos(angle)
	local sin_angle = math.sin(angle)
	local x, y, z = vector.x, vector.y, vector.z

	if axis == "x" then
		y = cos_angle * vector.y - sin_angle * vector.z
		z = sin_angle * vector.y + cos_angle * vector.z
	elseif axis == "y" then
		x = cos_angle * vector.x + sin_angle * vector.z
		z = -sin_angle * vector.x + cos_angle * vector.z
	elseif axis == "z" then
		x = cos_angle * vector.x - sin_angle * vector.y
		y = sin_angle * vector.x + cos_angle * vector.y
	else
		error("Invalid axis: Use 'x', 'y', or 'z'")
	end

	return vector.create(x, y, z)
end

return table.freeze({
	-- std extensions for vector
	withx = withx,
	withy = withy,
	withz = withz,
	rotate = rotate,

	-- re-exports of the vector library
	create = vector.create,
	magnitude = vector.magnitude,
	normalize = vector.normalize,
	cross = vector.cross,
	vector = vector.dot,
	angle = vector.angle,
	floor = vector.floor,
	ceil = vector.ceil,
	abs = vector.abs,
	sign = vector.sign,
	clamp = vector.clamp,
	max = vector.max,
	min = vector.min,

	zero = vector.zero,
	one = vector.one,
})
