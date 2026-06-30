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
# install rust to build openvasd and scannerctl
cd ..
#export RUST_BACKTRACE=full
#export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true
curl -o rustup.sh https://sh.rustup.rs
bash ./rustup.sh -y
. "$HOME/.cargo/env"

cd rust

# Pre-fetch cargo registry if crates.tar exists
if [ -f /rust/crates.tar ] && [ $(stat -c%s /rust/crates.tar) -ge 100 ]; then
    echo "Using pre-fetched crate cache"
    tar xvf /rust/crates.tar
fi

# Set up build-cache for native Rust crates if not provided by crates.tar
# The nasl-c-lib crate's build_support.rs expects static archives + headers in
# crates/nasl-c-lib/build-cache/archives/
SCANNER_RUST_DIR=$(pwd)
BUILD_CACHE="${SCANNER_RUST_DIR}/crates/nasl-c-lib/build-cache/archives"
if ! [ -d "${BUILD_CACHE}" ] || [ -z "$(ls -A "${BUILD_CACHE}/include/" 2>/dev/null)" ]; then
    echo "Setting up build-cache for native Rust crates from system packages..."
    mkdir -p "${BUILD_CACHE}/include"

    # Copy static libraries from system packages
    # These come from: libgcrypt20-dev, libgpg-error-dev, libpcap-dev, libkrb5-dev
    for lib in libgcrypt.a libgpg-error.a libpcap.a \
               libgssapi_krb5.a libkrb5.a libk5crypto.a \
               libcom_err.a libkrb5support.a; do
        found=$(find /usr -name "$lib" -print -quit 2>/dev/null || true)
        if [ -n "$found" ]; then
            cp -v "$found" "${BUILD_CACHE}/"
        else
            echo "WARNING: Static library $lib not found. Build may fail."
        fi
    done

    # Copy required headers (gcrypt.h, gpg-error.h from libgcrypt20-dev, libgpg-error-dev)
    for hdr in gcrypt.h gpg-error.h; do
        found=$(find /usr -name "$hdr" -print -quit 2>/dev/null || true)
        if [ -n "$found" ]; then
            cp -v "$found" "${BUILD_CACHE}/include/"
        else
            echo "WARNING: Header $hdr not found."
        fi
    done

    echo "Build-cache contents:"
    ls -la "${BUILD_CACHE}/"
    ls -la "${BUILD_CACHE}/include/"
fi

# Build openvasd
cd src/openvasd
cargo fetch --locked
if [ -f /rust/crates.tar ] && [ $(stat -c%s /rust/crates.tar) -ge 100 ]; then
    tar xvf /rust/crates.tar
    cargo build --frozen --release -vv
else
    cargo build --release -vv
fi

cd ../scannerctl
cargo fetch --locked
if [ -f /rust/crates.tar ] && [ $(stat -c%s /rust/crates.tar) -ge 100 ]; then
    cargo build --frozen --release -vv
else
    cargo build --release -vv
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
cp -v ../config/redis-openvas.conf $INSTALL_ROOT/etc/redis/
cd /build
rm -rf *
