#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBVIPS_DIR="$SCRIPT_DIR"

cd "$LIBVIPS_DIR"

echo "Cleaning old bindings and artifacts..."
rm -f vips/*.go vips/*.c vips/*.h vips/.libvips-version
rm -rf prebuilt/linux-amd64

echo "Phase 1: Building libvips static libraries with Zig..."
docker build -f build-vips.linux-amd64.Dockerfile --target artifacts -t libvips-builder .

echo "Extracting libvips static libraries..."
mkdir -p prebuilt/linux-amd64
# Extract artifacts from the scratch image using docker cp
CONTAINER_ID=$(docker create libvips-builder)
docker cp "$CONTAINER_ID:/usr/local/vips-dist/." prebuilt/linux-amd64/
docker rm "$CONTAINER_ID"

echo "Phase 2: Building vipsgen generator container..."
docker build -f vipsgen.Dockerfile -t vipsgen-builder .

echo "Generating vips bindings..."
docker run --rm -v $(pwd):/workspace vipsgen-builder vipsgen -out ./vips

# Fix permissions: files created by Docker are owned by root
echo "Fixing file permissions..."
sudo chown -R $(id -u):$(id -g) vips/*.go vips/*.c vips/*.h || true
sudo chown -R $(id -u):$(id -g) prebuilt/ || true
rm -rf prebuilt/linux-amd64/bin

LIBVIPS_VERSION=$(docker run --rm vipsgen-builder pkg-config --modversion vips)
echo "Bindings generated for libvips $LIBVIPS_VERSION with mozjpeg and HEIC support"

echo "$LIBVIPS_VERSION" >vips/.libvips-version

echo "Generated bindings are ready in $LIBVIPS_DIR/vips/"
echo "Static libraries are ready in $LIBVIPS_DIR/prebuilt/linux-amd64/"
echo "Use: make generate-vips-bindings to regenerate if needed"
echo "Use: USE_STATIC_LIBVIPS=1 make build to build with static libvips"
