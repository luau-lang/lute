return {
	host = "github.com",
	resolve = function(request)
		assert(request.protocol == "https")
		assert(request.host == "github.com")
		assert(request.path ~= nil)
		return "lute-credential-provider-test-token"
	end,
}
