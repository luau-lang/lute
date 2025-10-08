set -e

# function to display commands before running them
exe() { echo ": $@" ; "$@" ; }

fetch_dep() {
  local dep_file="$1"

  # Ensure the file exists
  if [[ ! -f "$dep_file" ]]; then
    echo "(ERR) dependency not found: $dep_file"
    return 1
  fi

  # Extract each field by key
  name=$(grep '^name' "$file" | sed -E 's/^name *= *"(.*)"/\1/')
  remote=$(grep '^remote' "$file" | sed -E 's/^remote *= *"(.*)"/\1/')
  branch=$(grep '^branch' "$file" | sed -E 's/^branch *= *"(.*)"/\1/')
  revision=$(grep '^revision' "$file" | sed -E 's/^revision *= *"(.*)"/\1/')

  # Output the parsed variables
  local target_dir="extern/$name"
  # Get version string (e.g., "git version 2.50.1")
  version_str=$(git --version)

  # Extract the major and minor version numbers using regex
  # e.g., 2 and 50 from "git version 2.50.1"
  if [[ $version_str =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
    gitMajor="${BASH_REMATCH[1]}"
    gitMinor="${BASH_REMATCH[2]}"

    # Now perform the version check
    if [[ "$gitMajor" -ge 3 || ( "$gitMajor" -eq 2 && "$gitMinor" -ge 49 ) ]]; then
      exe git clone --depth=1 --revision $revision $remote $target_dir
    else
      exe git clone --depth=1 --branch $branch $remote $target_dir
    fi
  else
    echo "(EE) could not parse Git version from: $version_str"
    exit 1
  fi
}

# Download dependencies from the tune files
find "extern" -mindepth 1 ! -name "*.tune" -prune -exec rm -rf {} +

for file in extern/*.tune; do
  if [[ -f "$file" ]]; then
    echo "(II) fetching dependency from: $(basename "$file")"
    fetch_dep "extern/$(basename "$file")"
  fi
done

# Generate the stdlib modules.cpp file
rm -rf lute/std/src/generated
mkdir -p lute/std/src/generated

exe cp ./tools/templates/std_impl.cpp ./lute/std/src/generated/modules.cpp
exe cp ./tools/templates/std_header.h ./lute/std/src/generated/modules.h

# Generate the clicommands modules.cpp file
rm -rf lute/cli/generated
mkdir -p lute/cli/generated

exe cp ./tools/templates/cli_impl.cpp ./lute/cli/generated/commands.cpp
exe cp ./tools/templates/cli_header.h ./lute/cli/generated/commands.h

## Configure bootstrap lute - lute stdlib
os_type="$(uname)"
BUILD_PATH=""
EXE_PATH=lute/cli/lute
OUT_BINARY=./build/lute0
if [[ "$os_type" == "Darwin" ]]; then
  BUILD_PATH=build/xcode/debug
elif [[ "$os_type" == MINGW* || "$os_type" == MSYS* || "$os_type" == CYGWIN* ]]; then
  BUILD_PATH=build/vs2022/debug
  EXE_PATH+=".exe"
  OUT_BINARY+=.exe
else
  build_path=BUILD/DEBUG
fi

rm -rf build && mkdir build
exe cmake -G=Ninja -B $BUILD_PATH -DCMAKE_BUILD_TYPE=Debug

# Compile bootstrapping lute
exe ninja -C $BUILD_PATH $EXE_PATH
echo ""
echo "(II) Successfully built lute0 without the standard library."

# Use lute0 to build lute with the standard library included.
BOOTSTRAPPED_LUTE=./$BUILD_PATH/$EXE_PATH

mv $BOOTSTRAPPED_LUTE $OUT_BINARY
exe $OUT_BINARY tools/luthier.luau build --clean lute

# optionally install the final built lute version
install_requested=false
# Parse flags
# Loop through all command-line arguments
for arg in "$@"; do
  if [[ "$arg" == "--install" ]]; then
    install_requested=true
    break
  fi
done

INSTALL_DIR=$HOME/.lute/bin
if $install_requested; then
  # TODO: give the lute executable a self-install subcommand and just invoke that here instead
  read -p "Enter the path where you would like to install lute to (default: $INSTALL_DIR): " USER_PATH

  # If user_input is empty, keep default_path; else update it
  if [[ -n "$USER_PATH" ]]; then
    INSTALL_DIR=$USER_PATH
  fi
  mkdir -p $INSTALL_DIR
  cp $BOOTSTRAPPED_LUTE $INSTALL_DIR
  echo ""
  echo "Installed lute to $INSTALL_DIR/lute. Make sure to add this to your PATH variable."
fi
