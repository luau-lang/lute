#!/usr/bin/env bash

set -e
install_requested=false

# simple argument parsing
for arg in "$@"; do
  if [[ "$arg" == "--install" ]]; then
    install_requested=true
    break
  fi
done

# function to display commands before running them
exe() { echo ": $@" ; "$@" ; }

fetch_dependency() {
  local dep_file="$1"

  # check the file exists
  if [[ ! -f "$dep_file" ]]; then
    echo "missing dependency file: $dep_file"
    return 1
  fi

  # extract each field by key
  name=$(grep '^name' "$file" | sed -E 's/^name *= *"(.*)"/\1/')
  remote=$(grep '^remote' "$file" | sed -E 's/^remote *= *"(.*)"/\1/')
  branch=$(grep '^branch' "$file" | sed -E 's/^branch *= *"(.*)"/\1/')
  revision=$(grep '^revision' "$file" | sed -E 's/^revision *= *"(.*)"/\1/')

  # output the parsed variables
  local target_dir="extern/$name"

  # get git's version string to determine whether to use revision or branch clones (e.g., "git version 2.50.1")
  version_str=$(git --version)
  # Extract the major and minor version numbers using regex
  # e.g., 2 and 50 from "git version 2.50.1"
  if [[ $version_str =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
    gitMajor="${BASH_REMATCH[1]}"
    gitMinor="${BASH_REMATCH[2]}"

    # git 2.49 added support for `--revision` to `git clone`
    if [[ "$gitMajor" -ge 3 || ( "$gitMajor" -eq 2 && "$gitMinor" -ge 49 ) ]]; then
      exe git clone --depth=1 --revision $revision $remote $target_dir
    else
      exe git clone --depth=1 --branch $branch $remote $target_dir
    fi
  else
    echo "ill-formed git version string: $version_str"
    exit 1
  fi
}

# download dependencies from the tune files
find "extern" -mindepth 1 ! -name "*.tune" -prune -exec rm -rf {} +
for file in extern/*.tune; do
  if [[ -f "$file" ]]; then
    echo "fetching $(basename "$file")"
    fetch_dependency "extern/$(basename "$file")"
  fi
done

# place empty versions of the standard library
rm -rf lute/std/src/generated
mkdir -p lute/std/src/generated

exe cp ./tools/templates/std_impl.cpp ./lute/std/src/generated/modules.cpp
exe cp ./tools/templates/std_header.h ./lute/std/src/generated/modules.h

# place empty versions of the luau-based lute subcommands for the cli
rm -rf lute/cli/generated
mkdir -p lute/cli/generated

exe cp ./tools/templates/cli_impl.cpp ./lute/cli/generated/commands.cpp
exe cp ./tools/templates/cli_header.h ./lute/cli/generated/commands.h

## configure the build system for lute0
os_type="$(uname)"
BUILD_ROOT=""
EXE_PATH=lute/cli/lute
OUT_BINARY=./build/lute0
if [[ "$os_type" == "Darwin" ]]; then
  BUILD_ROOT=build/xcode
elif [[ "$os_type" == MINGW* || "$os_type" == MSYS* || "$os_type" == CYGWIN* ]]; then
  BUILD_ROOT=build/vs2022
  EXE_PATH+=".exe"
  OUT_BINARY+=.exe
else
  BUILD_ROOT=build
fi

BUILD_PATH=$BUILD_ROOT/debug
rm -rf build && mkdir build
exe cmake -G=Ninja -B $BUILD_PATH -DCMAKE_BUILD_TYPE=Debug

# build lute0
exe ninja -C $BUILD_PATH $EXE_PATH
echo ""
echo "built lute0 at $BUILD_PATH/$EXE_PATH"

# use lute0 to build lute with the standard library included.
LUTESTRAP=./$BUILD_PATH/$EXE_PATH
mv $LUTESTRAP $OUT_BINARY
exe $OUT_BINARY tools/luthier.luau configure --config release --clean lute
exe $OUT_BINARY tools/luthier.luau build --config release --clean lute

# optionally install the final built lute version
INSTALL_DIR=$HOME/.lute/bin
BUILD_PATH=$BUILD_ROOT/release
LUTESTRAP=./$BUILD_PATH/$EXE_PATH
if $install_requested; then
  # TODO: give the lute executable a self-install subcommand and just invoke that here instead
  read -p "where would you like to install lute? (default: $INSTALL_DIR): " USER_PATH

  # If user_input is empty, keep default_path; else update it
  if [[ -n "$USER_PATH" ]]; then
    INSTALL_DIR=$USER_PATH
  fi
  mkdir -p $INSTALL_DIR
  cp $LUTESTRAP $INSTALL_DIR
  echo ""
  echo "installed lute to $INSTALL_DIR/lute"
  echo "please ensure this is accessible on your \$PATH"
fi
