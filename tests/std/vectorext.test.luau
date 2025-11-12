local test = require("@std/test")
local vectorext = require("@std/vectorext")

test.suite("VectorExt", function(suite)
	suite:case("withx_withy_withz", function(assert)
		local v = vector.create(1, 2, 3)

		local vx = vectorext.withx(v, 10)
		assert.eq(vx.x, 10)
		assert.eq(vx.y, 2)
		assert.eq(vx.z, 3)

		local vy = vectorext.withy(v, 20)
		assert.eq(vy.x, 1)
		assert.eq(vy.y, 20)
		assert.eq(vy.z, 3)

		local vz = vectorext.withz(v, 30)
		assert.eq(vz.x, 1)
		assert.eq(vz.y, 2)
		assert.eq(vz.z, 30)
	end)
end)

test.run()
