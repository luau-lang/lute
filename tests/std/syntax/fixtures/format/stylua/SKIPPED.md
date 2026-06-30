# Skipped StyLua Fixtures

These StyLua fixtures are not in the active Lute formatter snapshot corpus yet.
The remaining skipped cases are parser/grammar or parse-recovery issues, not formatter idempotence failures.

- `inputs/ambiguous-syntax-3.lua`: parse-or-format-failed - (1, 0) - (1, 1): Ambiguous syntax: this looks like an argument list for a function call, but could also be a start of new statement; use ';' to separate statements
- `inputs/ambiguous-syntax.lua`: parse-or-format-failed - (1, 0) - (1, 1): Ambiguous syntax: this looks like an argument list for a function call, but could also be a start of new statement; use ';' to separate statements
- `inputs/double-unary-minus.lua`: parse-or-format-failed - (3, 0) - (3, 5): Expected identifier when parsing expression, got 'local'
- `inputs/excess-parentheses.lua`: parse-or-format-failed - (12, 0) - (12, 1): Ambiguous syntax: this looks like an argument list for a function call, but could also be a start of new statement; use ';' to separate statements
- `inputs/large-example-2.lua`: parse-or-format-failed - (648, 49) - (648, 55): Malformed string; did you forget to finish it?
- `inputs/large-example.lua`: parse-or-format-failed - (621, 1) - (621, 6): Incomplete statement: expected assignment or a function call
- `inputs/string-brackets-index.lua`: parse-or-format-failed - (1, 10) - (1, 11): Expected '}' (to close '{' at line 1), got ']'
- `inputs-luau/ambiguous-syntax-1.lua`: parse-or-format-failed - (5, 1) - (5, 2): Ambiguous syntax: this looks like an argument list for a function call, but could also be a start of new statement; use ';' to separate statements
- `inputs-luau/compound-assignment-ambiguous-syntax.lua`: parse-or-format-failed - (6, 0) - (6, 1): Ambiguous syntax: this looks like an argument list for a function call, but could also be a start of new statement; use ';' to separate statements
- `inputs-luau/string-brackets-index.lua`: parse-or-format-failed - (1, 18) - (1, 19): Expected '}' (to close '{' at line 1), got ']'
- `inputs-luau/string-interpolation-table.lua`: parse-or-format-failed - (0, 10) - (0, 11): Double braces are not permitted within interpolated strings; did you mean '\{'?
- `inputs-luau/type-ascription-ambiguous-syntax.lua`: parse-or-format-failed - (1, 0) - (1, 1): Ambiguous syntax: this looks like an argument list for a function call, but could also be a start of new statement; use ';' to separate statements
- `inputs-luau-full_moon/attributes.lua`: parse-or-format-failed - (0, 0) - (0, 8): Invalid attribute '@example'
- `inputs-luau-full_moon/string_interpolation_double_brace.lua`: parse-or-format-failed - (0, 10) - (0, 11): Double braces are not permitted within interpolated strings; did you mean '\{'?
