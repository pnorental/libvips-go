#!/bin/bash

# Rebuilds libvips static libraries and generates Go bindings using Docker.
# Phase 1: Build static libvips with Zig toolchain
# Phase 2: Generate Go bindings with vipsgen tool

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Clean previous artifacts
rm -f vips/*.go vips/*.c vips/*.h vips/.libvips-version
rm -rf prebuilt/linux-amd64

# Build static libvips libraries
docker build -f build-vips.linux-amd64.Dockerfile --target artifacts -t libvips-builder .

# Extract static libraries from container
mkdir -p prebuilt/linux-amd64
CONTAINER_ID=$(docker create libvips-builder)
docker cp "$CONTAINER_ID:/usr/local/vips-dist/." prebuilt/linux-amd64/
docker rm "$CONTAINER_ID"

# Generate Go bindings
docker build -f vipsgen.Dockerfile -t vipsgen-builder .
docker run --rm -v $(pwd):/workspace vipsgen-builder vipsgen -out ./vips

# Fix Docker file ownership and cleanup
sudo chown -R $(id -u):$(id -g) vips/*.go vips/*.c vips/*.h || true
sudo chown -R $(id -u):$(id -g) prebuilt/ || true
rm -rf prebuilt/linux-amd64/bin

# Record libvips version
LIBVIPS_VERSION=$(docker run --rm vipsgen-builder pkg-config --modversion vips)
echo "$LIBVIPS_VERSION" >vips/.libvips-version

echo "Generated libvips $LIBVIPS_VERSION bindings with mozjpeg and HEIC support"
