#!/bin/bash
set -euo pipefail

PRELUDE_REPO="https://github.com/facebook/buck2-prelude.git"
PRELUDE_REV="main"
PRELUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)/prelude"

if [ -d "$PRELUDE_DIR/.git" ]; then
    echo "Prelude already fetched at $PRELUDE_DIR"
    exit 0
fi

echo "Fetching buck2 prelude..."
git clone --depth 1 --branch "$PRELUDE_REV" "$PRELUDE_REPO" "$PRELUDE_DIR"
echo "Done."
