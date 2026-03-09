local process = require("@std/process")

local bashScript = require("@self/bash")
local fishScript = require("@self/fish")
local zshScript = require("@self/zsh")

local args = { ... }

local USAGE = [[Usage: lute completion <shell> [options]
Generate tab-completion scripts for your shell.

Shells:
    bash          Bourne Again Shell.
    fish          Friendly Interactive Shell.
    zsh           Z Shell.

Options:
    -h, --help    Display this usage message.

Setup:
    Enable tab completion for lute commands, flags, and .lute scripts.

    To install, add one of the following to your shell configuration:

    Bash (~/.bashrc):
        eval "$(lute completion bash)"

    Fish (~/.config/fish/config.fish):
        lute completion fish | source

    Zsh (~/.zshrc):
        eval "$(lute completion zsh)"]]

if #args == 0 or table.find(args, "-h") or table.find(args, "--help") then
	print(USAGE)
	return
end

local shell = args[1]

if shell == "bash" then
	print(bashScript)
elseif shell == "fish" then
	print(fishScript)
elseif shell == "zsh" then
	print(zshScript)
else
	print(`Error: unsupported shell '{shell}'. Supported values: bash, fish, zsh`)
	process.exit(1)
end
