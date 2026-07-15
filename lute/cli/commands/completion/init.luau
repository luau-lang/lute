local cli = require("@batteries/cli")
local process = require("@std/process")

local bashScript = require("@self/bash")
local fishScript = require("@self/fish")
local zshScript = require("@self/zsh")

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

local args = cli.parser()
args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
args:add("shell", "positional", { help = "Shell type (bash, fish, zsh)" })
args:parse({ ... })

local shell = args:get("shell")

if shell == nil or args:has("help") then
	print(USAGE)
	return
end

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
