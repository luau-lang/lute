-- lute-lint-global-ignore(unused_variable)
local keyring = {}

--- Stores `password` under (`service`, `account`) in the OS-native credential store.
--- Replaces any existing value. Errors if the platform has no credential store
--- backend (see `keyring.isSupported`).
function keyring.set(service: string, account: string, password: string): ()
	error("not implemented")
end

--- Retrieves the password stored under (`service`, `account`).
--- Returns `nil` if no entry exists. Errors only on real backend failures.
function keyring.get(service: string, account: string): string?
	error("not implemented")
end

--- Deletes the entry stored under (`service`, `account`). Idempotent: succeeds
--- even if no entry exists.
function keyring.delete(service: string, account: string): ()
	error("not implemented")
end

--- Returns `true` if the running platform has a native credential store backend
--- (currently macOS Keychain and Windows Credential Manager).
function keyring.isSupported(): boolean
	error("not implemented")
end

return keyring
