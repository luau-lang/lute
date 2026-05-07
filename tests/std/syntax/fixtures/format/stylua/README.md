These fixtures are copied from the StyLua formatter test inputs:
https://github.com/JohnnyMorganz/StyLua/tree/main/tests

They are used as input-compatibility cases for Lute's opinionated formatter.
The test suite asserts that each copied fixture formats successfully and reaches
an idempotent fixed point under Lute's fixed policy. It intentionally does not
assert exact StyLua snapshot parity for configuration-specific behavior.
