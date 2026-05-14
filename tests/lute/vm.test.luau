local test = require("@std/test")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

test.suite("LuteVmSuite", function(suite)
	suite:case("childVmHasAccessToBuiltins", function(assert)
		local tmpdir = system.tmpdir()
		local child_vm = path.join(tmpdir, "child_vm.luau")
		local parent_vm = path.join(tmpdir, "parent_vm.luau")

		do
			local handle = fs.open(child_vm, "w+")
			assert.that(fs.exists(child_vm))
			fs.write(
				handle,
				[[
                local std_test_exists = require("@std/test") ~= nil
                local std_test_consistent = require("@std/test") == require("@std/test")
                local lute_vm_exists = require("@lute/vm") ~= nil
                local lute_vm_consistent = require("@lute/vm") == require("@lute/vm")

                local exported = {}

                function exported.std_test_exists()
                    return std_test_exists
                end
                function exported.std_test_consistent()
                    return std_test_consistent
                end
                function exported.lute_vm_exists()
                    return lute_vm_exists
                end
                function exported.lute_vm_consistent()
                    return lute_vm_consistent
                end

                return exported
            ]]
			)
			fs.close(handle)
		end

		do
			local handle = fs.open(parent_vm, "w+")
			assert.that(fs.exists(parent_vm))
			fs.write(
				handle,
				[[
                local vm = require("@lute/vm")
                local result = vm.create("./child_vm")
                assert(result.std_test_exists())
                assert(result.std_test_consistent())
                assert(result.lute_vm_exists())
                assert(result.lute_vm_consistent())
            ]]
			)
			fs.close(handle)
		end

		local result = process.run({ path.format(process.execPath()), path.format(parent_vm) })
		assert.eq(result.exitcode, 0)

		fs.remove(child_vm)
		fs.remove(parent_vm)
	end)

	suite:case("vectorCrossesVmBoundary", function(assert)
		local tmpdir = system.tmpdir()
		local child_vm = path.join(tmpdir, "child_vm_vector.luau")
		local parent_vm = path.join(tmpdir, "parent_vm_vector.luau")

		do
			local handle = fs.open(child_vm, "w+")
			assert.that(fs.exists(child_vm))
			fs.write(
				handle,
				[[
                local exported = {}

                function exported.roundtrip(v)
                    return v
                end

                function exported.make(x, y, z)
                    return vector.create(x, y, z)
                end

                function exported.inTable(t)
                    return t.v
                end

                return exported
            ]]
			)
			fs.close(handle)
		end

		do
			local handle = fs.open(parent_vm, "w+")
			assert.that(fs.exists(parent_vm))
			fs.write(
				handle,
				[[
                local vm = require("@lute/vm")
                local result = vm.create("./child_vm_vector")

                local v = vector.create(1.5, -2.25, 3.5)
                local r = result.roundtrip(v)
                assert(typeof(r) == "vector")
                assert(r.x == 1.5 and r.y == -2.25 and r.z == 3.5)

                local m = result.make(4, 5, 6)
                assert(typeof(m) == "vector")
                assert(m.x == 4 and m.y == 5 and m.z == 6)

                local nested = result.inTable({ v = vector.create(7, 8, 9) })
                assert(typeof(nested) == "vector")
                assert(nested.x == 7 and nested.y == 8 and nested.z == 9)
            ]]
			)
			fs.close(handle)
		end

		local result = process.run({ path.format(process.execPath()), path.format(parent_vm) })
		assert.eq(result.exitcode, 0)

		fs.remove(child_vm)
		fs.remove(parent_vm)
	end)
end)
