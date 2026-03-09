return [==[
#compdef lute

_lute_discover_scripts() {
    local dir="$PWD"
    local -A seen
    local -a builtins=(run check compile setup lint test transform doc pkg completion)
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.lute" ]]; then
            for f in "$dir/.lute"/*.luau(N) "$dir/.lute"/*.lua(N); do
                [[ -f "$f" ]] || continue
                local name="${f:t:r}"
                if (( ! ${+seen[$name]} )) && (( ! ${builtins[(Ie)$name]} )); then
                    seen[$name]=1
                    echo "$name"
                fi
            done
            for d in "$dir/.lute"/*(N/); do
                if [[ -f "$d/init.luau" || -f "$d/init.lua" ]]; then
                    local name="${d:t}"
                    if (( ! ${+seen[$name]} )) && (( ! ${builtins[(Ie)$name]} )); then
                        seen[$name]=1
                        echo "$name"
                    fi
                fi
            done
        fi
        dir="${dir:h}"
    done
}

_lute_luau_files() {
    _files -g '*.{luau,lua}'
}

_lute_scripts_and_luau_files() {
    local -a scripts
    scripts=(${(f)"$(_lute_discover_scripts)"})
    (( $#scripts )) && compadd -X '.lute script' -- $scripts
    _lute_luau_files
}

_lute() {
    local context state state_descr line
    typeset -A opt_args

    _arguments -C \
        '(-h --help)'{-h,--help}'[Display help message]' \
        '--version[Show lute version]' \
        '1:command:->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a commands=(
                'run:Run a Luau script'
                'check:Type check Luau files'
                'compile:Compile into standalone executable'
                'setup:Generate type definition files'
                'lint:Run linting rules'
                'test:Run tests'
                'transform:Run code transformation'
                'doc:Generate documentation'
                'pkg:Package management'
                'completion:Generate shell completion scripts'
            )
            _describe 'command' commands
            _lute_scripts_and_luau_files
            ;;
        args)
            case $words[1] in
                run)
                    _arguments \
                        '--profile[Enable profiling]' \
                        '--profile-output[Profile output file]:file:_files' \
                        '--frequency[Profiler sampling frequency (Hz)]:frequency' \
                        '(-h --help)'{-h,--help}'[Display help message]' \
                        '*:file:_lute_scripts_and_luau_files'
                    ;;
                check)
                    _arguments \
                        '(-h --help)'{-h,--help}'[Display help message]' \
                        '*:file:_lute_luau_files'
                    ;;
                compile)
                    _arguments \
                        '--output[Output executable name]:file:_files' \
                        '--bundle-stats[Show bundle statistics]' \
                        '--show-require-graph[Print dependency graph]' \
                        '(-h --help)'{-h,--help}'[Display help message]' \
                        '*:file:_lute_luau_files'
                    ;;
                setup)
                    _arguments \
                        '--with-luaurc[Write aliases to .luaurc]'
                    ;;
                lint)
                    _arguments \
                        '(-h --help)'{-h,--help}'[Display help message]' \
                        '(-v --verbose)'{-v,--verbose}'[Enable verbose output]' \
                        '(-r --rules)'{-r,--rules}'[Lint rule path]:file:_files' \
                        '(-c --config)'{-c,--config}'[Config file path]:file:_files' \
                        '(-j --json)'{-j,--json}'[JSON output]' \
                        '(-s --string-input)'{-s,--string-input}'[Lint string input]:string' \
                        '--auto-fix[Auto-apply fixes]' \
                        '--no-default-lints[Disable default rules]' \
                        '*:file:_lute_luau_files'
                    ;;
                test)
                    _arguments \
                        '(-h --help)'{-h,--help}'[Display help message]' \
                        '--list[List test cases]' \
                        '(-s --suite)'{-s,--suite}'[Run specific suite]:suite' \
                        '(-c --case)'{-c,--case}'[Run specific test case]:case' \
                        '(-i --interactive)'{-i,--interactive}'[Interactive snapshot review]' \
                        '(-u --update)'{-u,--update}'[Auto-accept snapshot changes]' \
                        '*:directory:_files -/'
                    ;;
                transform)
                    _arguments \
                        '--dry-run[Preview without writing]' \
                        '--output[Output file path]:file:_files' \
                        '*:file:_lute_luau_files'
                    ;;
                doc)
                    _arguments \
                        '(-h --help)'{-h,--help}'[Display help message]' \
                        '(-o --output)'{-o,--output}'[Output directory]:directory:_files -/' \
                        '*:directory:_files -/'
                    ;;
                pkg)
                    local -a pkg_commands=(
                        'run:Run with package awareness'
                        'install:Install packages'
                    )
                    _describe 'pkg command' pkg_commands
                    ;;
                completion)
                    compadd bash fish zsh
                    ;;
            esac
            ;;
    esac
}

compdef _lute lute
]==]
