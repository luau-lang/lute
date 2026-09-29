return {
	host = "registry.example.com",
	resolve = function(request)
		assert(request.protocol == "http")
		assert(request.host == "registry.example.com")
		return "lute-credential-provider-test-token"
	end,
}
