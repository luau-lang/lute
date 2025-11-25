type DequeNode<T> = {
	value: T,
	next: DequeNode<T>?,
	prev: DequeNode<T>?,
}

function dequeNode<T>(value: T, next: DequeNode<T>?, prev: DequeNode<T>?)
	return {
		value = value,
		next = next,
		prev = prev,
	}
end

type Deque<T> = {
	head: DequeNode<T>?,
	tail: DequeNode<T>?,
	prepend: (self: Deque<T>, value: T) -> (),
	append: (self: Deque<T>, value: T) -> (),
	pop: (self: Deque<T>) -> T, -- return value at front of queue
	len: number,
}

local deque = {}

function deque.new<T>(initValue: T)
	-- linked list; can pop from front or back easily
	-- keep track of head and tail; efficiently add to/pop from head and tail
	local self = {} :: Deque<T>
	local linkedList = dequeNode(initValue)
	self.head = linkedList
	self.tail = linkedList
	self.len = 1

	function self.prepend(self: Deque<T>, value: T)
		print("prepending")
		local newHead = dequeNode(value, self.head)
		if self.head then
			self.head.prev = newHead
		else
			self.tail = newHead
		end
		self.head = newHead
		self.len += 1
	end

	function self.append(self: Deque<T>, value: T)
		print("appending")
		local newTail = dequeNode(value, nil, self.tail)
		if self.tail then
			self.tail.next = newTail
		else
			self.head = newTail
		end
		self.tail = newTail
		self.len += 1
	end

	function self.pop(self: Deque<T>): T
		-- remove head (get front of queue)
		if not self.head then
			error("Popping from empty deque")
		end
		local curHead = self.head
		local newHead = self.head.next
		if newHead then
			newHead.prev = nil
		else
			self.tail = nil
		end
		self.head = newHead
		self.len -= 1
		return curHead.value
	end

	return self
end

return deque
