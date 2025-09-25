# CLAUDE.md

This file guides Claude Code (claude.ai/code) when you work with code in this repository.

This project creates Go bindings for the libvips image library. The vipsgen tool generates code based on a statically linked version of libvips. This approach creates bindings for specific libvips versions and avoids runtime dependency issues.

## Commands

Build static libs and generate bindings:
`./generate-vips-bindings.sh`

Compile with static linking:
`./with-static.sh go build`
`./with-static.sh go test`

## Key files

- `vips/` - Generated bindings (do not edit)
- `prebuilt/linux-amd64/` - Static libvips libraries
- `generate-vips-bindings.sh` - Rebuilds everything using Docker
- `with-static.sh` - Compiles with static libvips using Zig

The vipsgen tool reads libvips C headers to create the generated code.
