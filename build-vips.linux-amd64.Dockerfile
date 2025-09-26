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
    # HEIF/HEIC reading support (libheif built from source, libde265 from Alpine)
    libde265-static \
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

# Build libheif statically for reading HEIC files (no x265 encoder needed)
ARG LIBHEIF_VERSION=1.19.5
RUN wget -q https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz && \
    tar xf libheif-${LIBHEIF_VERSION}.tar.gz && \
    cd libheif-${LIBHEIF_VERSION} && \
    mkdir build && cd build && \
    cmake -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_EXAMPLES=OFF \
    -DWITH_X265=OFF \
    -DWITH_DAV1D=OFF \
    -DWITH_RAV1E=OFF \
    -DWITH_SvtEnc=OFF \
    -DWITH_AOM_DECODER=OFF \
    -DWITH_AOM_ENCODER=OFF \
    -DWITH_JPEG_DECODER=OFF \
    -DWITH_JPEG_ENCODER=OFF \
    -DENABLE_PLUGIN_LOADING=OFF \
    -DBUILD_TESTING=OFF \
    .. && \
    make -j$(nproc) heif && \
    # Install only the core library and headers manually
    cp libheif/libheif.a /usr/local/lib/ && \
    mkdir -p /usr/local/include/libheif && \
    cp ../libheif/api/libheif/*.h /usr/local/include/libheif/ && \
    # Copy generated version header
    cp libheif/heif_version.h /usr/local/include/libheif/ && \
    # Create simplified libheif.pc for static linking
    mkdir -p /usr/local/lib/pkgconfig && \
    printf 'prefix=/usr/local\nexec_prefix=${prefix}\nlibdir=${exec_prefix}/lib\nincludedir=${prefix}/include\n\nName: libheif\nDescription: HEIF file format decoder (static)\nVersion: 1.19.5\nLibs: -L${libdir} -lheif -lde265\nCflags: -I${includedir}\n' > /usr/local/lib/pkgconfig/libheif.pc && \
    cd /src && rm -rf libheif-${LIBHEIF_VERSION} libheif-${LIBHEIF_VERSION}.tar.gz

# Build libvips statically with Alpine's native static support
ARG VIPS_VERSION=8.16.1
RUN wget -q https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz && \
    tar xf vips-${VIPS_VERSION}.tar.xz && \
    cd vips-${VIPS_VERSION} && \
    # Remove fuzz, test, and tools subdirectories from build to avoid static linking issues
    sed -i '/^subdir.*fuzz.*$/d' meson.build && \
    sed -i '/^subdir.*test.*$/d' meson.build && \
    sed -i '/^subdir.*tools.*$/d' meson.build && \
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
    -Dgtk_doc=false \
    -Dheif=enabled \
    -Dheif-module=disabled \
    -Dfuzzing_engine=none && \
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
    sed -i 's|Libs: -L${libdir} -lvips -pthread -lm|Libs: -L${libdir} -lvips -lglib-2.0 -lgio-2.0 -lgobject-2.0 -lgmodule-2.0 -lintl -lffi -lpcre2-8 -lz -lmount -lblkid -leconf -lexpat -ljpeg -lpng16 -lwebp -lsharpyuv -lwebpmux -lwebpdemux -lheif -lde265 -lzstd -lstdc++ -pthread -lm|' /usr/local/vips-dist/lib/pkgconfig/vips.pc && \
    # Show what we built
    echo "Static libvips built successfully" && \
    echo "Available static libraries:" && \
    find /usr/local/vips-dist/lib -name "*.a" | wc -l && \
    echo "Available headers:" && \
    find /usr/local/vips-dist/include -name "*.h" | wc -l

FROM scratch AS artifacts
COPY --from=builder /usr/local/vips-dist /usr/local/vips-dist
CMD ["echo", "libvips artifacts ready"]
