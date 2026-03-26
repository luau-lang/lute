local test = require("@std/test")

local crypto = require("@lute/crypto")

test.suite("CryptoRuntimeTests", function(suite)
	suite:case("secretboxIsARoundtripStrings", function(assert)
		local message = "Remember, remember the Fifth of November."
		local box = crypto.secretbox.seal(message)

		local opened = crypto.secretbox.open(box)
		local output = buffer.readstring(opened, 0, buffer.len(opened))

		assert.eq(output, message)
	end)

	suite:case("secretboxIsARoundtripBuffers", function(assert)
		local message = "Gunpowder, treason, and plot."
		local buf = buffer.create(#message)
		buffer.writestring(buf, 0, message)

		local box = crypto.secretbox.seal(buf)
		local opened = crypto.secretbox.open(box)

		assert.eq(opened, buf)
	end)

	suite:case("secretboxSeparateKeygen", function(assert)
		local key = crypto.secretbox.keygen()

		local message = "Remember, remember the Fifth of November."
		local box = crypto.secretbox.seal(message, key)

		local opened = crypto.secretbox.open(box)
		local output = buffer.readstring(opened, 0, buffer.len(opened))

		assert.eq(output, message)
	end)

	suite:case("secretboxErrorsOnTampering", function(assert)
		local message = "Gunpowder, treason, and plot."
		local buf = buffer.create(#message)
		buffer.writestring(buf, 0, message)

		local box = crypto.secretbox.seal(buf)
		buffer.writeu32(box.ciphertext, 2, 10_11_2025)

		assert.errors(function()
			crypto.secretbox.open(box)
		end)
	end)

	suite:case("secretboxNoOpenString", function(assert)
		local message = "I see no reason why gunpowder treason should ever be forgot."

		local buf = buffer.create(#message)
		buffer.writestring(buf, 0, message)

		local box = crypto.secretbox.seal(buf)
		local other = {
			ciphertext = buffer.readstring(box.ciphertext, 0, #message),
			nonce = box.nonce,
			key = box.key,
		}

		assert.errors(function()
			-- We are testing that this fails when `ciphertext` is a string
			-- rather than a buffer, so we must lie to Luau.
			crypto.secretbox.open(other :: any)
		end)
	end)

	suite:case("secretboxMissizedKey", function(assert)
		local message = "I see no reason why gunpowder treason should ever be forgot."

		local buf = buffer.create(#message)
		buffer.writestring(buf, 0, message)

		local box = crypto.secretbox.seal(buf)
		local other = {
			ciphertext = box.ciphertext,
			nonce = box.nonce,
			key = buffer.create(5),
		}

		assert.errors(function()
			crypto.secretbox.open(other)
		end)
	end)

	suite:case("secretboxOnIllTypedInputs", function(assert)
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
			crypto.secretbox.open({ ciphertext = message, key = buffer.create(0), nonce = "woof" } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open({ ciphertext = message, key = "woof", nonce = buffer.create(0) } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open({ ciphertext = message } :: any)
		end)

		assert.errors(function()
			crypto.secretbox.open(nil :: any)
		end)
	end)
end)
