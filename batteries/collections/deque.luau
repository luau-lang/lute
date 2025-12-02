export type Deque<T> = {
	values: { [number]: T },
	pushfront: (self: Deque<T>, value: T) -> (),
	pushback: (self: Deque<T>, value: T) -> (),
	popfront: (self: Deque<T>) -> T,
	popback: (self: Deque<T>) -> T,
	peekfront: (self: Deque<T>) -> T,
	peekback: (self: Deque<T>) -> T,
	len: number,
}

local deque = {}

function deque.new<T>(initValue: T?): Deque<T>
	local self = {} :: Deque<T>
	self.values = {}
	local head, tail = 0, if initValue then 0 else -1
	self.len = if initValue then 1 else 0
	if initValue then
		self.values[head] = initValue
		self.values[tail] = initValue
	end

	function self.pushfront(self: Deque<T>, value: T)
		self.len += 1
		head -= 1
		self.values[head] = value
	end

	function self.pushback(self: Deque<T>, value: T)
		self.len += 1
		tail += 1
		self.values[tail] = value
	end

	function self.popfront(self: Deque<T>): T
		if self.len < 1 then
			error("Popping from empty deque")
		end
		self.len -= 1
		local toReturn = self.values[head]
		self.values[head] = nil
		head += 1
		return toReturn
	end

	function self.popback(self: Deque<T>): T
		if self.len < 1 then
			error("Popping from empty deque")
		end
		self.len -= 1
		local toReturn = self.values[tail]
		self.values[tail] = nil
		tail -= 1
		return toReturn
	end

	function self.peekfront(self: Deque<T>)
		return self.values[head]
	end
	function self.peekback(self: Deque<T>)
		return self.values[tail]
	end

	return self
end

return table.freeze(deque)
