export type DequeNode<T> = {
	value: T,
	next: DequeNode<T>?,
	prev: DequeNode<T>?,
}

function dequeNode<T>(value: T?, next: DequeNode<T>?, prev: DequeNode<T>?): DequeNode<T>?
	if not value then
		return nil
	end

	return {
		value = value,
		next = next,
		prev = prev,
	}
end

export type Deque<T> = {
	head: DequeNode<T>?,
	tail: DequeNode<T>?,
	pushfront: (self: Deque<T>, value: T) -> (),
	pushback: (self: Deque<T>, value: T) -> (),
	popfront: (self: Deque<T>) -> T, -- return value at front of queue
	popback: (self: Deque<T>) -> T,
	len: number,
}

local deque = {}

function deque.new<T>(initValue: T?)
	-- linked list; can pop from front or back easily
	-- keep track of head and tail; efficiently add to/pop from head and tail
	local self = {} :: Deque<T>
	local initNode = dequeNode(initValue)
	self.head = initNode
	self.tail = initNode
	self.len = if initNode then 1 else 0

	function self.pushfront(self: Deque<T>, value: T)
		local newHead = dequeNode(value, self.head)
		if self.head then
			self.head.prev = newHead
		else
			self.tail = newHead
		end
		self.head = newHead
		self.len += 1
	end

	function self.pushback(self: Deque<T>, value: T)
		local newTail = dequeNode(value, nil, self.tail)
		if self.tail then
			self.tail.next = newTail
		else
			self.head = newTail
		end
		self.tail = newTail
		self.len += 1
	end

	function self.popfront(self: Deque<T>): T
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

	function self.popback(self: Deque<T>): T
		if not self.tail then
			error("Popping from empty deque")
		end

		local curTail = self.tail
		local newTail = self.tail.prev
		if newTail then
			newTail.next = nil
		else -- one node in deq
			self.head = nil
		end
		self.tail = newTail
		self.len -= 1
		return curTail.value
	end

	return self
end

return deque
