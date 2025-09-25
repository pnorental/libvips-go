FROM golang:1.25.0-alpine

# Install required tools for Zig static compilation
RUN apk add --no-cache \
    wget \
    xz \
    pkgconfig \
    musl-dev

# Install Zig compiler for static linking
ARG ZIG_VERSION=0.15.1
RUN wget -q https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz && \
    tar -xf zig-x86_64-linux-${ZIG_VERSION}.tar.xz && \
    mv zig-x86_64-linux-${ZIG_VERSION} /opt/zig && \
    ln -s /opt/zig/zig /usr/local/bin/zig && \
    rm zig-x86_64-linux-${ZIG_VERSION}.tar.xz

# Copy pre-built static libvips libraries and headers from Alpine build
COPY prebuilt/linux-amd64/ /usr/local/

# Configure environment for static linking with Zig and musl
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV CC="zig cc -target x86_64-linux-musl"
ENV CXX="zig c++ -target x86_64-linux-musl"
ENV CGO_ENABLED=1
ENV CGO_LDFLAGS="-static"
ENV CGO_CPPFLAGS="-I/usr/local/include/glib-2.0 -I/usr/local/include/glib-2.0/include"

# Install vipsgen generator
RUN go install github.com/cshum/vipsgen/cmd/vipsgen@latest

WORKDIR /workspace

# Default command to show libvips version
CMD ["sh", "-c", "echo 'libvips version:' && pkg-config --modversion vips"]