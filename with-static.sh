#!/usr/bin/env bash

# Script to run Go commands with static libvips compilation using Zig
# Usage: ./libvips/with-static.sh go test ./internal/images
# Usage: ./libvips/with-static.sh make build

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREBUILT_DIR="$SCRIPT_DIR/prebuilt/linux-amd64"

# Check if static libraries exist
if [[ ! -d "$PREBUILT_DIR/lib" ]] || [[ ! -f "$PREBUILT_DIR/lib/libvips.a" ]]; then
    echo "Error: Static libvips libraries not found at $PREBUILT_DIR/lib/libvips.a"
    echo "Run 'make generate-vips-bindings' first to build them"
    exit 1
fi

# Check if Zig is available
if ! command -v zig &> /dev/null; then
    echo "Error: Zig compiler not found. Please install Zig 0.15.1 or later"
    echo "Download from: https://ziglang.org/download/"
    exit 1
fi

# Set up environment for static libvips compilation with Zig
export PKG_CONFIG_PATH="$PREBUILT_DIR/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# Configure Zig as the C/C++ compiler for static musl builds
export CC="zig cc -target x86_64-linux-musl"
export CXX="zig c++ -target x86_64-linux-musl"
export CGO_ENABLED=1
export CGO_LDFLAGS="-static -L$PREBUILT_DIR/lib"
export CGO_CPPFLAGS="-I$PREBUILT_DIR/include -I$PREBUILT_DIR/include/glib-2.0 -I$PREBUILT_DIR/include/glib-2.0/include"

# Execute the command
exec "$@"