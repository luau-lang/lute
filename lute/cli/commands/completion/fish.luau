return [==[
# Disable default file completion
complete -c lute -f

# Helper function for .lute script discovery
function __lute_discover_scripts
    set -l dir (pwd)
    set -l builtins run check compile setup lint test transform doc pkg new completion
    while test "$dir" != "/"
        if test -d "$dir/.lute"
            for f in $dir/.lute/*.luau $dir/.lute/*.lua
                test -f "$f"; or continue
                set -l name (string replace -r '\.(luau|lua)$' '' (basename $f))
                if not contains -- $name $builtins
                    echo $name
                end
            end
            for d in $dir/.lute/*/
                test -d "$d"; or continue
                if test -f "$d/init.luau" -o -f "$d/init.lua"
                    set -l name (basename $d)
                    if not contains -- $name $builtins
                        echo $name
                    end
                end
            end
        end
        set dir (string replace -r '/[^/]*$' '' $dir)
        test -z "$dir"; and set dir "/"
    end | sort -u
end

# Condition: no subcommand yet
function __lute_needs_command
    set -l tokens (commandline -opc)
    for i in (seq 2 (count $tokens))
        switch $tokens[$i]
            case '-*'
                continue
            case '*'
                return 1
        end
    end
    return 0
end

# Condition: specific subcommand is active
function __lute_using_subcommand
    set -l tokens (commandline -opc)
    for i in (seq 2 (count $tokens))
        switch $tokens[$i]
            case '-*'
                continue
            case '*'
                test "$tokens[$i]" = "$argv[1]"; and return 0
                return 1
        end
    end
    return 1
end


# Top-level commands
complete -c lute -n __lute_needs_command -a run -d "Run a Luau script"
complete -c lute -n __lute_needs_command -a check -d "Type check Luau files"
complete -c lute -n __lute_needs_command -a compile -d "Compile into standalone executable"
complete -c lute -n __lute_needs_command -a setup -d "Generate type definition files"
complete -c lute -n __lute_needs_command -a lint -d "Run linting rules"
complete -c lute -n __lute_needs_command -a test -d "Run tests"
complete -c lute -n __lute_needs_command -a transform -d "Run code transformation"
complete -c lute -n __lute_needs_command -a doc -d "Generate documentation"
complete -c lute -n __lute_needs_command -a pkg -d "Package management"
complete -c lute -n __lute_needs_command -a new -d "Create a new Lute project"
complete -c lute -n __lute_needs_command -a completion -d "Generate shell completion"

# .lute scripts (dynamic)
complete -c lute -n __lute_needs_command -a "(__lute_discover_scripts)" -d ".lute script"

# Allow file completion at top level (for implicit 'run')
complete -c lute -n __lute_needs_command -F

# Global options
complete -c lute -n __lute_needs_command -s h -l help -d "Display help message"
complete -c lute -n __lute_needs_command -l version -d "Show lute version"

# run
complete -c lute -n "__lute_using_subcommand run" -l profile -d "Enable profiling"
complete -c lute -n "__lute_using_subcommand run" -l profile-output -r -d "Profile output file"
complete -c lute -n "__lute_using_subcommand run" -l frequency -r -d "Profiler sampling frequency (Hz)"
complete -c lute -n "__lute_using_subcommand run" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand run" -a "(__lute_discover_scripts)" -d ".lute script"
complete -c lute -n "__lute_using_subcommand run" -F

# check
complete -c lute -n "__lute_using_subcommand check" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand check" -F

# compile
complete -c lute -n "__lute_using_subcommand compile" -l output -r -d "Output executable name"
complete -c lute -n "__lute_using_subcommand compile" -l bundle-stats -d "Show bundle statistics"
complete -c lute -n "__lute_using_subcommand compile" -l show-require-graph -d "Print dependency graph"
complete -c lute -n "__lute_using_subcommand compile" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand compile" -F

# setup
complete -c lute -n "__lute_using_subcommand setup" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand setup" -l with-luaurc -d "Write aliases to .luaurc"

# lint
complete -c lute -n "__lute_using_subcommand lint" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand lint" -s v -l verbose -d "Enable verbose output"
complete -c lute -n "__lute_using_subcommand lint" -s r -l rules -r -d "Lint rule path"
complete -c lute -n "__lute_using_subcommand lint" -s c -l config -r -d "Config file path"
complete -c lute -n "__lute_using_subcommand lint" -s j -l json -d "JSON output"
complete -c lute -n "__lute_using_subcommand lint" -s s -l string-input -r -d "Lint string input"
complete -c lute -n "__lute_using_subcommand lint" -l auto-fix -d "Auto-apply fixes"
complete -c lute -n "__lute_using_subcommand lint" -l no-default-lints -d "Disable default rules"
complete -c lute -n "__lute_using_subcommand lint" -F

# test
complete -c lute -n "__lute_using_subcommand test" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand test" -l list -d "List test cases"
complete -c lute -n "__lute_using_subcommand test" -s s -l suite -r -d "Run specific suite"
complete -c lute -n "__lute_using_subcommand test" -s c -l case -r -d "Run specific test case"
complete -c lute -n "__lute_using_subcommand test" -s i -l interactive -d "Interactive snapshot review"
complete -c lute -n "__lute_using_subcommand test" -s u -l update -d "Auto-accept snapshot changes"
complete -c lute -n "__lute_using_subcommand test" -s v -l verbose -d "Enable verbose output"
complete -c lute -n "__lute_using_subcommand test" -F

# transform
complete -c lute -n "__lute_using_subcommand transform" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand transform" -l dry-run -d "Preview without writing"
complete -c lute -n "__lute_using_subcommand transform" -s o -l output -r -d "Output file path"
complete -c lute -n "__lute_using_subcommand transform" -F

# doc
complete -c lute -n "__lute_using_subcommand doc" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand doc" -s o -l output -r -d "Output directory"
complete -c lute -n "__lute_using_subcommand doc" -F

# pkg condition: pkg is the active subcommand AND no pkg subcommand has been chosen yet
function __lute_pkg_needs_subcommand
    set -l tokens (commandline -opc)
    set -l seen_pkg 0
    for i in (seq 2 (count $tokens))
        switch $tokens[$i]
            case '-*'
                continue
            case '*'
                if test $seen_pkg -eq 1
                    return 1
                end
                if test "$tokens[$i]" = "pkg"
                    set seen_pkg 1
                else
                    return 1
                end
        end
    end
    test $seen_pkg -eq 1
end

# pkg subcommands: only offered before a pkg subcommand has been typed
complete -c lute -n __lute_pkg_needs_subcommand -a "run" -d "Run with package awareness"
complete -c lute -n __lute_pkg_needs_subcommand -a "install" -d "Install packages"
complete -c lute -n __lute_pkg_needs_subcommand -a "auth" -d "Save authentication token"
complete -c lute -n __lute_pkg_needs_subcommand -s h -l help -d "Display help message"

# pkg auth options: active once "auth" follows "pkg"
function __lute_pkg_auth
    set -l tokens (commandline -opc)
    set -l seen 0
    for i in (seq 2 (count $tokens))
        switch $tokens[$i]
            case '-*'
                continue
            case '*'
                if test $seen -eq 1
                    test "$tokens[$i]" = "auth"; and return 0
                    return 1
                end
                test "$tokens[$i]" = "pkg"; and set seen 1
        end
    end
    return 1
end
complete -c lute -n __lute_pkg_auth -l token -r -d "Authentication token"
complete -c lute -n __lute_pkg_auth -l domain -r -d "Domain (default: github.com)"

# new
complete -c lute -n "__lute_using_subcommand new" -s h -l help -d "Display help message"

# completion
complete -c lute -n "__lute_using_subcommand completion" -s h -l help -d "Display help message"
complete -c lute -n "__lute_using_subcommand completion" -a "bash fish zsh" -d "Shell type"
]==]
