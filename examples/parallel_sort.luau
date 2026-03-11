local vm = require("@lute/vm")

local task = require("@std/task")

local function getslice(t, n: number, m: number)
	local size = math.ceil(#t / m)

	local slice = table.create(size)
	table.move(t, 1 + (n - 1) * size, n * size, 1, slice)
	return slice
end

local function merge<T>(t1: { T }, t2: { T }, comp: (T, T) -> lt<T>)
	local t = table.create(#t1 + #t2)
	local pos1, pos2, pos = 1, 1, 1

	while pos1 < #t1 and pos2 < #t2 do
		if comp(t1[pos1], t2[pos2]) then
			t[pos] = t1[pos1]
			pos += 1
			pos1 += 1
		else
			t[pos] = t2[pos2]
			pos += 1
			pos2 += 1
		end
	end

	while pos1 < #t1 do
		t[pos] = t1[pos1]
		pos += 1
		pos1 += 1
	end

	while pos2 < #t2 do
		t[pos] = t2[pos2]
		pos += 1
		pos2 += 1
	end

	return t
end

local threadCount = 8
local threads: { { [any]: any } } = {}

for _ = 1, threadCount do
	table.insert(threads, vm.create("./parallel_sort_helper"))
end

local function parallelMergeSort<T>(t: { T }, comp: (T, T) -> lt<T>): { T }
	local slices = {}

	for i = 1, threadCount do
		table.insert(slices, task.create(threads[i].sort, getslice(t, i, threadCount)))
	end

	local tomerge = table.pack(task.awaitall(table.unpack(slices)))
	tomerge.n = nil :: any

	while #tomerge > 1 do
		local next = {}
		for i = 1, #tomerge, 2 do
			-- LUAUFIX: we should not need to explicitly cast these arrays to {T}
			table.insert(next, merge(tomerge[i] :: { T }, tomerge[i + 1] :: { T }, comp))
		end

		tomerge = next
	end

	return tomerge[1]
end

local size = 1_000_000

local t = table.create(size, 0)

for i in t do
	t[i] = math.random(1, 10000000)
end

local t2 = table.clone(t)

local startseq = os.clock()
table.sort(t, function(a: number, b: number)
	return a < b
end)
print("sequential in:", os.clock() - startseq)

local startparallel = os.clock()
-- LUAUFIX: we should not need to explicitly instantiate the type here
t2 = parallelMergeSort<<number>>(t2, function(a, b)
	return a < b
end)
print("parallel in:", os.clock() - startparallel)

print("part for comparison")

for i = #t / 2 - 5, #t / 2 + 5 do
	print(t[i], t2[i])
end
