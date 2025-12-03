export type Deque<T> = {
	_head: number,
	_tail: number,
	_values: { [number]: T },
	pushfront: (self: Deque<T>, value: T) -> (),
	pushback: (self: Deque<T>, value: T) -> (),
	popfront: (self: Deque<T>) -> T,
	popback: (self: Deque<T>) -> T,
	peekfront: (self: Deque<T>) -> T?,
	peekback: (self: Deque<T>) -> T?,
}

local deque = {}
deque.__index = deque
deque.__len = function<T>(self: Deque<T>)
	return self._tail - self._head + 1
end

local dequeLib = {}

function dequeLib.new<T>(initValue: T?): Deque<T>
	local self = {} :: Deque<T>
	self._values = {}
	self._head, self._tail = 0, if initValue then 0 else -1
	if initValue then
		self._values[self._head] = initValue
		self._values[self._tail] = initValue
	end

	return setmetatable(self, deque)
end

function deque.pushfront<T>(self: Deque<T>, value: T)
	self._head -= 1
	self._values[self._head] = value
end

function deque.pushback<T>(self: Deque<T>, value: T)
	self._tail += 1
	self._values[self._tail] = value
end

function deque.popfront<T>(self: Deque<T>): T
	if self._tail < self._head then
		error("Popping from empty deque")
	end
	local toReturn = self._values[self._head]
	self._values[self._head] = nil
	self._head += 1
	return toReturn
end

function deque.popback<T>(self: Deque<T>): T
	if self._tail < self._head then
		error("Popping from empty deque")
	end
	local toReturn = self._values[self._tail]
	self._values[self._tail] = nil
	self._tail -= 1
	return toReturn
end

function deque.peekfront<T>(self: Deque<T>)
	return self._values[self._head]
end

function deque.peekback<T>(self: Deque<T>)
	return self._values[self._tail]
end

return table.freeze(dequeLib)
