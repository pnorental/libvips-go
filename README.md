# libvips-go

Go bindings for the libvips image library. The vipsgen tool generates code based on a statically linked version of libvips. This approach creates bindings for specific libvips versions and avoids runtime dependency issues.

## Usage

Build static libs and generate bindings:
```bash
./generate-vips-bindings.sh
```

Compile Go programs with static libvips:
```bash
./with-static.sh go build
./with-static.sh go test
```

The `with-static.sh` script configures the environment to use Zig compiler with static libvips libraries, creating fully self-contained binaries.

## Project structure

- `vips/` - Generated bindings (do not edit)
- `prebuilt/linux-amd64/` - Static libvips libraries
- `generate-vips-bindings.sh` - Rebuilds everything using Docker
- `with-static.sh` - Compiles with static libvips using Zig

The vipsgen tool reads libvips C headers to create the generated code.
