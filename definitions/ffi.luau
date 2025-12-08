--!strict

type function AccessPhantom(t: type)
	if t.tag == "function" then
		local parameters = t:parameters()
		local returns = t:returns()

		if parameters.head then
			for i, param in parameters.head do
				parameters.head[i] = AccessPhantom(parameters.head[i])
			end
		end

		if parameters.tail then
			parameters.tail = AccessPhantom(parameters.tail)
		end

		if returns.head then
			for i, param in returns.head do
				returns.head[i] = AccessPhantom(returns.head[i])
			end
		end

		if returns.tail then
			returns.tail = AccessPhantom(returns.tail)
		end

		return types.newfunction(parameters, returns, t:generics())
	elseif t.tag == "table" then
		local prop = t:readproperty(types.singleton("__phantom"))

		if prop then
			return AccessPhantom(prop)
		else
			return t
		end
	end

	return t
end

type function LoadReturn(t: type)
	local result = {}

	for k, v in t:properties() do
		result[k] = AccessPhantom(v.read)
	end

	return types.newtable(result)
end


type function MakeStructFromUnions(inner: type): type
	local fields = if inner.tag == "union" then inner:components() else { inner }

	local new_fields = types.newtable()

	for _, field in fields do
		local ran = false

		for k, v in field:properties() do
			-- next doesnt work very well for types ig
			if ran then
				error("Struct field definitions must have exactly one key-value pair")
			end

			new_fields:setproperty(assert(k), AccessPhantom(v.read))
			ran = true
		end
	end

	return new_fields
end

type CType<T> = {
	__phantom: T,
}

local ffi = {
	c = {
		void = {} :: CType<nil>,

		char = {} :: CType<number>,
		uchar = {} :: CType<number>,
		int = {} :: CType<number>,
		uint = {} :: CType<number>,

		uint8 = {} :: CType<number>,
		int8 = {} :: CType<number>,
		uint16 = {} :: CType<number>,
		int16 = {} :: CType<number>,
		uint32 = {} :: CType<number>,
		int32 = {} :: CType<number>,

		float = {} :: CType<number>,
		double = {} :: CType<number>,

		-- not sure how this will need to be represented
		pointer = {} :: CType<{}>,
	},
}

function ffi.c.fn<R>(returntype: CType<R>): <T...>(T...) -> CType<(T...) -> R>
	error("not implemented")
end

function ffi.c.load<T>(libpath: string, lib: T): LoadReturn<T>
	error("not implemented")
end

function ffi.c.struct<T>(structdef: {T}): CType<MakeStructFromUnions<T>>
	error("not implemented")
end

function ffi.c.const<T>(value: CType<T>): CType<T>
	error("not implemented")
end

return ffi
