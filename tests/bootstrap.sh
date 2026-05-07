#!/usr/bin/env bash
# Fetches bats-core into tests/.bin if absent. Idempotent.
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BATS_DIR="$ROOT/tests/.bin/bats-core"
BATS_VERSION="v1.11.0"

if [ -x "$BATS_DIR/bin/bats" ]; then
  exit 0
fi

mkdir -p "$ROOT/tests/.bin"
TARBALL="$ROOT/tests/.bin/bats.tar.gz"

curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/${BATS_VERSION}.tar.gz" -o "$TARBALL"
tar -xzf "$TARBALL" -C "$ROOT/tests/.bin"
rm "$TARBALL"
mv "$ROOT/tests/.bin/bats-core-${BATS_VERSION#v}" "$BATS_DIR"
chmod +x "$BATS_DIR/bin/bats"

echo "bats-core ${BATS_VERSION} ready at $BATS_DIR"
