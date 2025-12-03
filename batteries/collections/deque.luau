export type Deque<T> = {
	__head: number,
	__tail: number,
	_values: { [number]: T },
	len: number,
	pushfront: (self: Deque<T>, value: T) -> (),
	pushback: (self: Deque<T>, value: T) -> (),
	popfront: (self: Deque<T>) -> T,
	popback: (self: Deque<T>) -> T,
	peekfront: (self: Deque<T>) -> T?,
	peekback: (self: Deque<T>) -> T?,
}

local deque = {}
deque.__len = function<T>(self: Deque<T>)
	return self.len
end
deque.__index = deque

function deque.new<T>(initValue: T?): Deque<T>
	local self = {} :: Deque<T>
	self._values = {}
	self.__head, self.__tail = 0, if initValue then 0 else -1
	self.len = if initValue then 1 else 0
	if initValue then
		self._values[self.__head] = initValue
		self._values[self.__tail] = initValue
	end

	return setmetatable(self, deque)
end

function deque.pushfront<T>(self: Deque<T>, value: T)
	self.len += 1
	self.__head -= 1
	self._values[self.__head] = value
end

function deque.pushback<T>(self: Deque<T>, value: T)
	self.len += 1
	self.__tail += 1
	self._values[self.__tail] = value
end

function deque.popfront<T>(self: Deque<T>): T
	if self.len < 1 then
		error("Popping from empty deque")
	end
	self.len -= 1
	local toReturn = self._values[self.__head]
	self._values[self.__head] = nil
	self.__head += 1
	return toReturn
end

function deque.popback<T>(self: Deque<T>): T
	if self.len < 1 then
		error("Popping from empty deque")
	end
	self.len -= 1
	local toReturn = self._values[self.__tail]
	self._values[self.__tail] = nil
	self.__tail -= 1
	return toReturn
end

function deque.peekfront<T>(self: Deque<T>)
	return self._values[self.__head]
end
function deque.peekback<T>(self: Deque<T>)
	return self._values[self.__tail]
end

return table.freeze(deque)
