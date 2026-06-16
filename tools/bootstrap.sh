#!/usr/bin/env bash

set -e
install_requested=false
use_ccache=false
build_config="release"

# simple argument parsing
for arg in "$@"; do
  if [[ "$arg" == "--install" ]]; then
    install_requested=true
  elif [[ "$arg" == "--with-ccache" ]]; then
    use_ccache=true
  elif [[ "$arg" == "--build-debug" ]]; then
    build_config="debug"
  fi
done

# function to display commands before running them
exe() { echo ": $@" ; "$@" ; }

stage_start() { STAGE_START=$SECONDS; echo "=== $1 ==="; }
stage_end() { echo "=== $1 completed in $((SECONDS - STAGE_START))s ==="; echo; }

fetch_dependency() {
  local dep_file="$1"

  # check the file exists
  if [[ ! -f "$dep_file" ]]; then
    echo "missing dependency file: $dep_file"
    return 1
  fi

  # extract each field by key
  local name=$(grep '^name' "$dep_file" | sed -E 's/^name *= *"(.*)"/\1/')
  local remote=$(grep '^remote' "$dep_file" | sed -E 's/^remote *= *"(.*)"/\1/')
  local branch=$(grep '^branch' "$dep_file" | sed -E 's/^branch *= *"(.*)"/\1/')
  local revision=$(grep '^revision' "$dep_file" | sed -E 's/^revision *= *"(.*)"/\1/')

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

stage_start "fetch dependencies"
find "extern" -mindepth 1 ! -name "*.tune" -prune -exec rm -rf {} +
for file in extern/*.tune; do
  if [[ -f "$file" ]]; then
    echo "fetching $(basename "$file")"
    fetch_dependency "extern/$(basename "$file")" &
  fi
done
wait

# Write the tune file hash so luthier's fetchDependenciesIfNeeded() becomes a no-op.
# Must match luthier.luau getTuneFilesHash().
mkdir -p extern/generated
{ for file in $(ls extern/*.tune | sort); do
    printf '%s' "$(basename "$file")"
    cat "$file"
  done
} | b2sum -l 256 | cut -d' ' -f1 | tr -d '\n' > extern/generated/hash.txt
stage_end "fetch dependencies"

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

# Use a dedicated directory for the STDLESS bootstrap build so that the
# cmake cache with LUTE_STDLESS=ON never contaminates the real debug build
# directory that luthier will configure afterwards.
BOOTSTRAP_BUILD_PATH=build/lute0-bootstrap
rm -rf build && mkdir build
CCACHE_FLAGS=""
if $use_ccache; then
  CCACHE_FLAGS="-DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER_LAUNCHER=ccache"
fi

stage_start "configure lute0"
exe cmake -G=Ninja -B $BOOTSTRAP_BUILD_PATH -DCMAKE_BUILD_TYPE=${build_config} -DLUTE_STDLESS=ON $CCACHE_FLAGS
stage_end "configure lute0"

# build lute0
stage_start "build lute0"
exe ninja -C $BOOTSTRAP_BUILD_PATH $EXE_PATH
stage_end "build lute0"
echo "built lute0 at $BOOTSTRAP_BUILD_PATH/$EXE_PATH"

# use lute0 to build lute with the standard library included.
LUTESTRAP=./$BOOTSTRAP_BUILD_PATH/$EXE_PATH
mv $LUTESTRAP $OUT_BINARY
LUTHIER_CCACHE=""
if $use_ccache; then
  LUTHIER_CCACHE="--with-ccache"
fi

stage_start "configure lute"
exe $OUT_BINARY tools/luthier.luau configure --config $build_config --clean $LUTHIER_CCACHE lute
stage_end "configure lute"

stage_start "build lute"
exe $OUT_BINARY tools/luthier.luau build --config $build_config --clean $LUTHIER_CCACHE lute
stage_end "build lute"

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
