FROM alpine:3.22.1 AS builder

# Install build tools and static libraries for libvips
RUN apk add --no-cache \
    build-base \
    meson \
    ninja \
    cmake \
    pkgconfig \
    git \
    # Core dependencies
    glib-dev \
    glib-static \
    expat-dev \
    expat-static \
    # PCRE2 (required by glib)
    pcre2-dev \
    pcre2-static \
    # Util-linux (for mount, blkid) and its dependencies
    util-linux-dev \
    util-linux-static \
    libeconf-dev \
    # Core static libraries
    zlib-dev \
    zlib-static \
    # Image format libraries (with static variants)
    libjpeg-turbo-dev \
    libjpeg-turbo-static \
    libpng-dev \
    libpng-static \
    libwebp-dev \
    libwebp-static \
    # Compression
    zstd-dev \
    zstd-static

# Set up build environment for static compilation
ENV PKG_CONFIG_PATH="/usr/lib/pkgconfig"
ENV LDFLAGS="-static -leconf"
ENV CFLAGS="-Os"
# Force pkg-config to prefer static libraries
ENV PKG_CONFIG="pkg-config --static"

WORKDIR /src


# Build libvips statically with Alpine's native static support
ARG VIPS_VERSION=8.16.1
RUN wget -q https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz && \
    tar xf vips-${VIPS_VERSION}.tar.xz && \
    cd vips-${VIPS_VERSION} && \
    meson setup builddir \
    --buildtype=release \
    --prefix=/usr/local \
    --libdir=lib \
    --default-library=static \
    --prefer-static \
    -Dintrospection=disabled \
    -Dmodules=disabled \
    -Dcplusplus=false \
    -Ddeprecated=false \
    -Dexamples=false \
    -Dvapi=false \
    -Ddoxygen=false \
    -Dgtk_doc=false && \
    cd builddir && \
    ninja && \
    ninja install && \
    cd /src && rm -rf vips-${VIPS_VERSION} vips-${VIPS_VERSION}.tar.xz

# Create distribution directory with static libraries and headers
RUN mkdir -p /usr/local/vips-dist && \
    cp -r /usr/local/lib /usr/local/vips-dist/ && \
    cp -r /usr/local/include /usr/local/vips-dist/ && \
    cp -r /usr/local/bin /usr/local/vips-dist/ && \
    # Copy Alpine's static libraries that libvips depends on
    mkdir -p /usr/local/vips-dist/lib && \
    find /usr/lib -name "*.a" -path "*/lib*" -exec cp {} /usr/local/vips-dist/lib/ \; && \
    # Copy all dependency headers from Alpine system directories
    mkdir -p /usr/local/vips-dist/include && \
    cp -r /usr/include/glib-2.0 /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/lib/glib-2.0/include /usr/local/vips-dist/include/glib-2.0/ 2>/dev/null || true && \
    cp -r /usr/include/expat.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/png.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/pngconf.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/pnglibconf.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/jpeglib.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/jconfig.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/jmorecfg.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/jerror.h /usr/local/vips-dist/include/ 2>/dev/null || true && \
    cp -r /usr/include/webp /usr/local/vips-dist/include/ 2>/dev/null || true && \
    # Create static-friendly vips.pc file (remove Requires, add static libs)
    sed -i '/^Requires:/d' /usr/local/vips-dist/lib/pkgconfig/vips.pc && \
    sed -i 's|Libs: -L${libdir} -lvips -pthread -lm|Libs: -L${libdir} -lvips -lglib-2.0 -lgio-2.0 -lgobject-2.0 -lgmodule-2.0 -lintl -lffi -lpcre2-8 -lz -lmount -lblkid -leconf -lexpat -ljpeg -lpng16 -lwebp -lsharpyuv -lwebpmux -lwebpdemux -lzstd -pthread -lm|' /usr/local/vips-dist/lib/pkgconfig/vips.pc && \
    # Show what we built
    echo "Static libvips built successfully" && \
    echo "Available static libraries:" && \
    find /usr/local/vips-dist/lib -name "*.a" | wc -l && \
    echo "Available headers:" && \
    find /usr/local/vips-dist/include -name "*.h" | wc -l

FROM scratch AS artifacts
COPY --from=builder /usr/local/vips-dist /usr/local/vips-dist
CMD ["echo", "libvips artifacts ready"]
