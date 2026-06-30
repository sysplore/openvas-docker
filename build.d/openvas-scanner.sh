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
# These expect static archives + headers in crates/nasl-c-lib/build-cache/archives/
SCANNER_RUST_DIR=$(pwd)
BUILD_CACHE="${SCANNER_RUST_DIR}/crates/nasl-c-lib/build-cache/archives"
echo "Setting up build-cache for native Rust crates from system packages..."
mkdir -p "${BUILD_CACHE}/include"

# Copy static libraries from system packages
for lib in libgcrypt.a libgpg-error.a libpcap.a \
           libgssapi_krb5.a libkrb5.a libk5crypto.a \
           libcom_err.a libkrb5support.a; do
    found=$(find /usr -name "$lib" -print -quit 2>/dev/null || true)
    if [ -n "$found" ]; then
        cp -v "$found" "${BUILD_CACHE}/"
    else
        echo "WARNING: Static library $lib not found."
    fi
done

# Copy required headers
for hdr in gcrypt.h gpg-error.h krb5.h; do
    found=$(find /usr -name "$hdr" -print -quit 2>/dev/null || true)
    if [ -n "$found" ]; then
        cp -v "$found" "${BUILD_CACHE}/include/"
    else
        echo "WARNING: Header $hdr not found."
    fi
done

# Copy gssapi headers
mkdir -p "${BUILD_CACHE}/include/gssapi"
for hdr in gssapi.h gssapi_krb5.h; do
    found=$(find /usr -name "$hdr" -print -quit 2>/dev/null || true)
    if [ -n "$found" ]; then
        cp -v "$found" "${BUILD_CACHE}/include/gssapi/"
    else
        echo "WARNING: Header gssapi/$hdr not found."
    fi
done

echo "Build-cache contents:"
ls -la "${BUILD_CACHE}/"
ls -la "${BUILD_CACHE}/include/" 2>/dev/null || true
ls -la "${BUILD_CACHE}/include/gssapi/" 2>/dev/null || true

# Build openvasd - the Rust-based Notus vulnerability detection daemon
echo "Building openvasd (Rust-based Notus scanner)..."
cd src/openvasd
# cargo fetches dependencies from the internet (no --frozen needed)
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
