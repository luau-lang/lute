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
			assert.eq(fs.exists(child_vm), true)
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
			assert.eq(fs.exists(parent_vm), true)
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

		local result = process.run({ path.format(process.execpath()), path.format(parent_vm) })
		assert.eq(result.exitcode, 0)

		fs.remove(child_vm)
		fs.remove(parent_vm)
	end)
end)
