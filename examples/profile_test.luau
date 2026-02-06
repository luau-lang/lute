-- Test program for profiler with deep call stacks and recursion

-- Fibonacci with recursion (creates deep stacks)
local function fibonacci(n: number): number
	if n <= 1 then
		return n
	end
	return fibonacci(n - 1) + fibonacci(n - 2)
end

-- Array processing with nested calls
local function processArray(arr: { number }, depth: number): number
	if depth == 0 then
		local sum = 0
		for _, v in arr do
			sum += v * v
		end
		return sum
	else
		local result = 0
		for i = 1, #arr do
			result += processArray({ arr[i], arr[i] * 2 }, depth - 1)
		end
		return result
	end
end

-- Nested function calls
local function innerWork(x: number): number
	local result = 0
	for i = 1, x do
		result += math.sin(i) * math.cos(i)
	end
	return result
end

local function middleWork(x: number): number
	local sum = 0
	for _ = 1, 10 do
		sum += innerWork(x)
	end
	return sum
end

-- Tree traversal (creates interesting call patterns)
type TreeNode = {
	value: number,
	left: TreeNode?,
	right: TreeNode?,
}

local function createTree(depth: number, value: number): TreeNode
	if depth == 0 then
		return { value = value, left = nil, right = nil }
	end
	return {
		value = value,
		left = createTree(depth - 1, value * 2),
		right = createTree(depth - 1, value * 2 + 1),
	}
end

local function sumTree(node: TreeNode?): number
	if node == nil then
		return 0
	end
	return node.value + sumTree(node.left) + sumTree(node.right)
end

-- Main test function
local function runTests()
	print("Starting profiler test...")

	print("Tree traversal")
	for i = 1, 5 do
		local tree = createTree(i, 1)
		local sum = sumTree(tree)
		print(`  Tree sum = {sum}`)
	end

	print("Mixed workload")
	for round = 1, 50 do
		local fib = fibonacci(15)
		local arr_result = processArray({ 1, 2, 3 }, 2)
		local work = middleWork(50)
		print(`  Round {round}: fib={fib}, arr={arr_result}, work={work}`)
	end

	print("\nProfiler test complete!")
end

runTests()
