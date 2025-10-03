set -e

fetch_dep() {
  local dep_file="$1"

  # Ensure the file exists
  if [[ ! -f "$dep_file" ]]; then
    echo "Dependency file not found: $dep_file"
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
      git clone --depth=1 --revision $revision $remote $target_dir
    else
      git clone --depth=1 --branch $branch $remote $target_dir
    fi
  else
    echo "Could not parse Git version from: $version_str"
    exit 1
  fi
}

# Download dependencies from the tune files
find "extern" -mindepth 1 ! -name "*.tune" -prune -exec rm -rf {} +

for file in extern/*.tune; do
  if [[ -f "$file" ]]; then
    echo "Fetching dependency from: $(basename "$file")"
    fetch_dep "extern/$(basename "$file")"
  fi
done

# Generate the stdlib modules.cpp file
rm -rf lute/std/src/generated
mkdir -p lute/std/src/generated

cp ./tools/templates/std_impl.cpp ./lute/std/src/generated/modules.cpp
cp ./tools/templates/std_header.h ./lute/std/src/generated/modules.h

# Generate the clicommands modules.cpp file
rm -rf lute/cli/generated
mkdir -p lute/cli/generated

cp ./tools/templates/cli_impl.cpp ./lute/cli/generated/commands.cpp
cp ./tools/templates/cli_header.h ./lute/cli/generated/commands.h

## Configure bootstrap lute - lute stdlib
os_type="$(uname)"
BUILD_PATH=""
EXE_PATH=lute/cli/lute
OUT_BINARY=./build/bootstrapped-lute
if [[ "$os_type" == "Linux" ]]; then
  BUILD_PATH=build/debug
elif [[ "$os_type" == "Darwin" ]]; then
  BUILD_PATH=build/xcode/debug
elif [[ "$os_type" == MINGW* || "$os_type" == MSYS* || "$os_type" == CYGWIN* ]]; then
    BUILD_PATH=build/vs2022/debug
    EXE_PATH+=".exe"
    OUT_BINARY+=.exe
else
  echo "Unknown OS: $os_type, cannot bootstrap"
  return 1
fi

rm -rf build && mkdir build
cmake -G=Ninja -B $BUILD_PATH -DCMAKE_BUILD_TYPE=Debug

# Compile bootstrapping lute
ninja -C $BUILD_PATH $EXE_PATH
echo ""
echo "Successfully built the bootstrapped lute - std"

# Use bootstrapped lute to build lute with standard libraries included
BOOTSTRAPPED_LUTE=./$BUILD_PATH/$EXE_PATH

mv $BOOTSTRAPPED_LUTE $OUT_BINARY
$OUT_BINARY tools/luthier.luau build --clean lute

# optionally install bootstrapped lute
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
