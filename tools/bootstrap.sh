#!bin/bash

fetch() {
  local dep_file="$1"

  # Ensure the file exists
  if [[ ! -f "$dep_file" ]]; then
    echo "Dependency file not found: $dep_file"
    return 1
  fi

  # Default values
  local name=""
  local remote=""
  local branch=""
  local revision=""

  # Parse the file
  while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | sed 's/"//g' | xargs)

    case "$key" in
      name) name="$value" ;;
      remote) remote="$value" ;;
      branch) branch="$value" ;;
      revision) revision="$value" ;;
    esac
  done < "$dep_file"

  local target_dir="../extern/$name"

  # Clone if not already present
  if [[ -d "$target_dir" ]]; then
    echo "Dependency '$name' already exists at $target_dir. Skipping clone."
  else
    echo "Cloning $name from $remote (branch: $branch) into $target_dir..."
    git clone --branch "$branch" --single-branch "$remote" "$target_dir" || return 1
  fi

  # Checkout specific revision if provided
  if [[ -n "$revision" ]]; then
    echo "Checking out revision $revision in $target_dir"
    git -C "$target_dir" checkout "$revision" || return 1
  fi
}

# Fetch all the dependencies
echo "Fetching dependencies..."
fetch "../extern/boringssl.tune"
fetch "../extern/curl.tune"
fetch "../extern/libsodium.tune"
fetch "../extern/luau.tune"
fetch "../extern/libuv.tune"
fetch "../extern/uSockets.tune"
fetch "../extern/uWebSockets.tune"
fetch "../extern/zlib.tune"

