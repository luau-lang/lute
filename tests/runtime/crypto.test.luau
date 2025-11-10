local test = require("@std/test")

local crypto = require("@lute/crypto")

test.suite("CryptoRuntimeTests", function(suite)
	suite:case("secretbox_is_a_roundtrip_strings", function(assert)
		local message = "Remember, remember the Fifth of November."
		local box = crypto.secretbox.seal(message)

		local opened = crypto.secretbox.open(box)
		local output = buffer.readstring(opened, 0, buffer.len(opened))

		assert.eq(output, message)
	end)

	suite:case("secretbox_is_a_roundtrip_buffers", function(assert)
		local message = "Gunpowder, treason, and plot."
		local buf = buffer.create(#message)
		buffer.writestring(buf, 0, message)

		local box = crypto.secretbox.seal(buf)
		local opened = crypto.secretbox.open(box)

		assert.buffereq(opened, buf)
	end)

	suite:case("secretbox_errors_on_tampering", function(assert)
		local message = "Gunpowder, treason, and plot."
		local buf = buffer.create(#message)
		buffer.writestring(buf, 0, message)

		local box = crypto.secretbox.seal(buf)
		buffer.writeu32(box.ciphertext, 2, 10_11_2025)

		assert.errors(function()
			crypto.secretbox.open(box)
		end)
	end)

	suite:case("secretbox_on_ill_typed_inputs", function(assert)
		local message = "I see no reason why gunpowder treason should ever be forgot."

		assert.errors(function()
			crypto.secretbox.seal({ message } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.seal({ message, message, message } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.seal({ ciphertext = message, key = message, nonce = message } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open(message :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open({ ciphertext = message, key = buffer.create(), nonce = "woof" } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open({ ciphertext = message, key = "woof", nonce = buffer.create() } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open({ ciphertext = message } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open(nil :: any)
		end)
	end)
end)

test.run()
