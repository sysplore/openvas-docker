#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
. build.d/env.sh
echo "Building openvas_scanner"
cd /build
wget --no-verbose https://github.com/greenbone/openvas-scanner/archive/$openvas.tar.gz
tar -zxf $openvas.tar.gz
cd /build/*/
# Install dev dependency
apt install -y libkrb5-dev libkdb5-10 libmagic-dev libcurl4-gnutls-dev \
            capnproto libclang-dev libpcap-dev \
            libsnmp-dev libssl-dev libgcrypt20-dev libgcrypt20 \
            libgpg-error-dev dpkg-dev

if [ $(arch) == "armv7l" ]; then
	sed -i "s/%lu/%i/g" src/attack.c
fi
mkdir -p build
cd build

cmake -DCMAKE_BUILD_TYPE=Release ..
#cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-g3" -DCMAKE_CXX_FLAGS="-g3" ..
make -j2
make install

# install rust to build openvasd (Rust-based Notus scanner) and scannerctl
# openvasd is the replacement for notus-scanner and eventually ospd-openvas
# See: https://github.com/greenbone/openvas-scanner/tree/main/rust
cd ..
curl -o rustup.sh https://sh.rustup.rs
bash ./rustup.sh -y
. "$HOME/.cargo/env"

cd rust

# Limit parallelism to avoid OOM during Rust compilation (aws-lc-sys is memory hungry)
export CARGO_BUILD_JOBS=2

# Set up build-cache for native Rust crates (libcrypt-sys, libopenvas-krb5-sys)
# Following the upstream approach from .docker/prod.Dockerfile:
# 1. Build MIT Kerberos from source for static libs (Debian packages don't ship .a files)
# 2. Use system packages for libgcrypt, libgpg-error static libs
SCANNER_RUST_DIR=$(pwd)
BUILD_CACHE="${SCANNER_RUST_DIR}/crates/nasl-c-lib/build-cache/archives"
echo "Setting up build-cache for native Rust crates..."
mkdir -p "${BUILD_CACHE}/include"
mkdir -p "${BUILD_CACHE}/include/gssapi"
mkdir -p "${BUILD_CACHE}/include/krb5"

# 1. Install needed dev packages for headers and gcrypt/gpg-error static libs
#    (libgcrypt20-dev and libgpg-error-dev already installed above)
DEB_HOST_MULTIARCH="$(gcc -print-multiarch)"
cp -v "/usr/lib/${DEB_HOST_MULTIARCH}/libgcrypt.a" "${BUILD_CACHE}/libgcrypt.a"
cp -v "/usr/lib/${DEB_HOST_MULTIARCH}/libgpg-error.a" "${BUILD_CACHE}/libgpg-error.a"
cp -v /usr/include/gcrypt.h "${BUILD_CACHE}/include/gcrypt.h"
cp -v "/usr/include/${DEB_HOST_MULTIARCH}/gpg-error.h" "${BUILD_CACHE}/include/gpg-error.h"

# 2. Build MIT Kerberos from source for static libraries
#    Debian libkrb5-dev doesn't ship .a files for most krb5 libs
KRB5_VERSION=1.20.1
KRB5_SRC="/tmp/krb5-${KRB5_VERSION}"
if ! [ -f "${BUILD_CACHE}/libgssapi_krb5.a" ]; then
    echo "Building MIT Kerberos ${KRB5_VERSION} from source for static libraries..."
    apt install -y bison 2>/dev/null || true
    cd /tmp
    curl -sL "https://kerberos.org/dist/krb5/${KRB5_VERSION}/krb5-${KRB5_VERSION}.tar.gz" -o "krb5-${KRB5_VERSION}.tar.gz"
    tar xzf "krb5-${KRB5_VERSION}.tar.gz"
    cd "krb5-${KRB5_VERSION}/src"
    ./configure --prefix=/opt/krb5-static \
        --enable-static \
        --disable-shared \
        --without-system-verto \
        --without-libedit \
        --disable-rpath \
        --quiet
    make -C util/support -j"$(nproc)" --quiet 2>/dev/null || make -C util/support -j2
    make -C util/et -j"$(nproc)" --quiet 2>/dev/null || make -C util/et -j2
    make -C util/profile -j"$(nproc)" --quiet 2>/dev/null || make -C util/profile -j2
    make -C include -j"$(nproc)" --quiet 2>/dev/null || make -C include -j2
    make -C lib/crypto -j"$(nproc)" --quiet 2>/dev/null || make -C lib/crypto -j2
    make -C lib/krb5 -j"$(nproc)" --quiet 2>/dev/null || make -C lib/krb5 -j2
    make -C lib/gssapi -j"$(nproc)" --quiet 2>/dev/null || make -C lib/gssapi -j2
    make install-mkdirs
    make -C util/support install
    make -C util/et install
    make -C util/profile install
    make -C include install
    make -C lib/crypto install
    make -C lib/krb5 install
    make -C lib/gssapi install
    # Clean up source
    rm -rf /tmp/krb5*
fi

# 3. Copy krb5 static libs to build-cache
cp -v /opt/krb5-static/lib/libgssapi_krb5.a "${BUILD_CACHE}/libgssapi_krb5.a"
cp -v /opt/krb5-static/lib/libkrb5.a "${BUILD_CACHE}/libkrb5.a"
cp -v /opt/krb5-static/lib/libk5crypto.a "${BUILD_CACHE}/libk5crypto.a"
cp -v /opt/krb5-static/lib/libcom_err.a "${BUILD_CACHE}/libcom_err.a"
cp -v /opt/krb5-static/lib/libkrb5support.a "${BUILD_CACHE}/libkrb5support.a"

# 4. Copy krb5 headers
cp -v /opt/krb5-static/include/krb5.h "${BUILD_CACHE}/include/krb5.h"
cp -v /opt/krb5-static/include/com_err.h "${BUILD_CACHE}/include/com_err.h"
cp -v /opt/krb5-static/include/profile.h "${BUILD_CACHE}/include/profile.h"
cp -v /opt/krb5-static/include/gssapi/gssapi.h "${BUILD_CACHE}/include/gssapi/gssapi.h"
cp -v /opt/krb5-static/include/gssapi/gssapi_krb5.h "${BUILD_CACHE}/include/gssapi/gssapi_krb5.h"
cp -v /opt/krb5-static/include/gssapi/gssapi_alloc.h "${BUILD_CACHE}/include/gssapi/gssapi_alloc.h" 2>/dev/null || true
cp -v /opt/krb5-static/include/gssapi/gssapi_ext.h "${BUILD_CACHE}/include/gssapi/gssapi_ext.h" 2>/dev/null || true
cp -v /opt/krb5-static/include/gssapi/gssapi_generic.h "${BUILD_CACHE}/include/gssapi/gssapi_generic.h" 2>/dev/null || true

# 5. Use system libpcap.a (Debian's libpcap-dev provides it)
cp -v /usr/lib/${DEB_HOST_MULTIARCH}/libpcap.a "${BUILD_CACHE}/libpcap.a" 2>/dev/null || \
    cp -v $(find /usr -name 'libpcap.a' -print -quit) "${BUILD_CACHE}/libpcap.a" 2>/dev/null || \
    echo "WARNING: libpcap.a not found"

echo "Build-cache contents:"
ls -la "${BUILD_CACHE}/"
ls -la "${BUILD_CACHE}/include/"
ls -la "${BUILD_CACHE}/include/gssapi/" 2>/dev/null || true

# Set environment variable so Rust crate build_support.rs finds our archives
export OPENVAS_ARCHIVES="${BUILD_CACHE}"

# Return to rust directory for cargo build
cd "${SCANNER_RUST_DIR}"

# Build openvasd - the Rust-based Notus vulnerability detection daemon
echo "Building openvasd (Rust-based Notus scanner)..."
cd src/openvasd
cargo build --release -vv
OPENVASD_EXIT=$?
if [ $OPENVASD_EXIT -ne 0 ]; then
    echo "ERROR: openvasd build failed with exit code $OPENVASD_EXIT"
    exit $OPENVASD_EXIT
fi

# Build scannerctl - utility tool for NASL testing and scanner management
echo "Building scannerctl..."
cd ../scannerctl
cargo build --release -vv
SCANNERCTL_EXIT=$?
if [ $SCANNERCTL_EXIT -ne 0 ]; then
    echo "ERROR: scannerctl build failed with exit code $SCANNERCTL_EXIT"
    exit $SCANNERCTL_EXIT
fi

cd ../..
echo "#####################################################"
echo "#####################################################"
echo "#####################################################"
find / -name openvasd
find / -name scannerctl
find / -name redis-openvas.conf
echo "#####################################################"
echo "#####################################################"
echo "#####################################################"
echo "Copy openvasd binaries to $INSTALL_ROOT"
cp -v ./target/release/openvasd $INSTALL_ROOT/bin/
cp -v ./target/release/scannerctl $INSTALL_ROOT/bin/
mkdir -p ${INSTALL_ROOT}etc/redis/
# Find and copy redis config
REDIS_CONF=$(find /build -maxdepth 3 -name redis-openvas.conf -print -quit 2>/dev/null || true)
if [ -n "$REDIS_CONF" ]; then
    cp -v "$REDIS_CONF" ${INSTALL_ROOT}etc/redis/
else
    echo "WARNING: redis-openvas.conf not found, creating minimal config"
    echo "unixsocket /run/redis/redis.sock" > ${INSTALL_ROOT}etc/redis/redis-openvas.conf
fi
cd /build
rm -rf *
