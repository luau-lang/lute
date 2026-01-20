#!/usr/bin/env bash
DEFAULT_SCRIPTNAME=${1:-profile.luau}
echo "profiling $DEFAULT_SCRIPTNAME"
xctrace record --template 'Time Profiler' --launch -- ./build/xcode/debug/lute/cli/lute $DEFAULT_SCRIPTNAME
