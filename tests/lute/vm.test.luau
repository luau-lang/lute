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

	suite:case("bufferCrossesVmBoundary", function(assert)
		local tmpdir = system.tmpdir()
		local child_vm = path.join(tmpdir, "child_vm_buffer.luau")
		local parent_vm = path.join(tmpdir, "parent_vm_buffer.luau")

		do
			local handle = fs.open(child_vm, "w+")
			assert.that(fs.exists(child_vm))
			fs.write(
				handle,
				[[
                local exported = {}

                function exported.roundtrip(b)
                    return b
                end

                function exported.make()
                    local b = buffer.create(4)
                    buffer.writeu8(b, 0, 10)
                    buffer.writeu8(b, 1, 20)
                    buffer.writeu8(b, 2, 30)
                    buffer.writeu8(b, 3, 40)
                    return b
                end

                function exported.inTable(t)
                    return t.b
                end

                function exported.mutateAndReturn(b)
                    buffer.writeu8(b, 0, 99)
                    return b
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
                local result = vm.create("./child_vm_buffer")

                local b = buffer.create(3)
                buffer.writeu8(b, 0, 1)
                buffer.writeu8(b, 1, 2)
                buffer.writeu8(b, 2, 3)

                -- roundtrip
                local r = result.roundtrip(b)
                assert(typeof(r) == "buffer")
                assert(buffer.len(r) == 3)
                assert(buffer.readu8(r, 0) == 1)
                assert(buffer.readu8(r, 1) == 2)
                assert(buffer.readu8(r, 2) == 3)

                -- make
                local m = result.make()
                assert(typeof(m) == "buffer")
                assert(buffer.len(m) == 4)
                assert(buffer.readu8(m, 0) == 10)
                assert(buffer.readu8(m, 3) == 40)

                -- inTable
                local src = buffer.create(2)
                buffer.writeu8(src, 0, 6)
                buffer.writeu8(src, 1, 7)
                local nested = result.inTable({ b = src })
                assert(typeof(nested) == "buffer")
                assert(buffer.readu8(nested, 0) == 6)
                assert(buffer.readu8(nested, 1) == 7)

                -- mutateAndReturn: child mutates a copy without affecting the parent
                local owned = buffer.create(2)
                buffer.writeu8(owned, 0, 50)
                buffer.writeu8(owned, 1, 60)
                local mutated = result.mutateAndReturn(owned)
                assert(buffer.readu8(owned, 0) == 50)
                assert(buffer.readu8(mutated, 0) == 99)
                assert(buffer.readu8(mutated, 1) == 60)
            ]]
			)
			fs.close(handle)
		end

		local result = process.run({ path.format(process.execPath()), path.format(parent_vm) })
		assert.eq(result.exitcode, 0)

		fs.remove(child_vm)
		fs.remove(parent_vm)
	end)

	suite:case("deeplyNestedTableError", function(assert)
		local tmpdir = system.tmpdir()
		local child_vm = path.join(tmpdir, "child_vm_deep.luau")
		local parent_vm = path.join(tmpdir, "parent_vm_deep.luau")

		do
			local handle = fs.open(child_vm, "w+")
			assert.that(fs.exists(child_vm))
			fs.write(handle, [[ return { echo = function(x: any): any return x end } ]])
			fs.close(handle)
		end

		do
			local handle = fs.open(parent_vm, "w+")
			assert.that(fs.exists(parent_vm))
			fs.write(
				handle,
				[[
                local vm = require("@lute/vm")
                local worker = vm.create("./child_vm_deep")

                local function createNestedTable(depth: number): { any }
                  local root = {}
                  local current = root

                  for _ = 1, depth do
                    current.next = {}
                    current = current.next
                  end

                  return root
                end

                worker.echo(createNestedTable(50000))
            ]]
			)
			fs.close(handle)
		end

		local result = process.run({ path.format(process.execPath()), path.format(parent_vm) })
		assert.eq(result.signal, nil)
		assert.neq(result.exitcode, 0)
		assert.strContains(result.stderr, "Failed to copy arguments between VMs")

		fs.remove(child_vm)
		fs.remove(parent_vm)
	end)

	suite:case("cyclicTableError", function(assert)
		local tmpdir = system.tmpdir()
		local child_vm = path.join(tmpdir, "child_vm_cycle.luau")
		local parent_vm = path.join(tmpdir, "parent_vm_cycle.luau")

		do
			local handle = fs.open(child_vm, "w+")
			assert.that(fs.exists(child_vm))
			fs.write(handle, [[ return { echo = function(x: any): any return x end } ]])
			fs.close(handle)
		end

		do
			local handle = fs.open(parent_vm, "w+")
			assert.that(fs.exists(parent_vm))
			fs.write(
				handle,
				[[
                local vm = require("@lute/vm")
                local worker = vm.create("./child_vm_cycle")

                local root = {}
                root.self = root

                worker.echo(root)
            ]]
			)
			fs.close(handle)
		end

		local result = process.run({ path.format(process.execPath()), path.format(parent_vm) })
		assert.eq(result.signal, nil)
		assert.neq(result.exitcode, 0)
		assert.strContains(result.stderr, "Failed to copy arguments between VMs")

		fs.remove(child_vm)
		fs.remove(parent_vm)
	end)
end)
