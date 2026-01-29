To add a new default lint rule to `lute lint`, create a module or luau file defining the rule in this folder. 
Then, add the name of the rule to the DEFAULT_RULES constant in `lint/init.luau`, add a test for the rule in `tests/cli/lint.test.luau`, and add documentation for it in `docs/cli/lint`.
The expected type of a lint rule is specified in `lint/types.luau`. 