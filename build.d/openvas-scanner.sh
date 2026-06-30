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
# Limit parallelism to avoid OOM during Rust compilation
export CARGO_BUILD_JOBS=2

# Try to build Rust components (openvasd, scannerctl) if crates.tar is available
if [ -f /rust/crates.tar ] && [ $(stat -c%s /rust/crates.tar) -ge 100 ]; then
    echo "Pre-fetched crate cache found. Building Rust components..."
    tar xvf /rust/crates.tar

    # Build openvasd
    cd src/openvasd
    cargo fetch --locked
    cargo build --frozen --release -vv || echo "WARNING: openvasd build failed, continuing without it"

    cd ../scannerctl
    cargo fetch --locked
    cargo build --frozen --release -vv || echo "WARNING: scannerctl build failed, continuing without it"

    cd ../..
    echo "#####################################################"
    find / -name openvasd -o -name scannerctl 2>/dev/null || true
    echo "#####################################################"

    # Copy binaries if they were built
    if [ -f ./target/release/openvasd ]; then
        cp -v ./target/release/openvasd $INSTALL_ROOT/bin/
    fi
    if [ -f ./target/release/scannerctl ]; then
        cp -v ./target/release/scannerctl $INSTALL_ROOT/bin/
    fi
else
    echo "No pre-fetched crate cache available. Skipping Rust component build."
    echo "Container will use ospd-openvas + notus-scanner architecture instead of openvasd."
fi

# Copy redis config (always needed)
mkdir -p ${INSTALL_ROOT}etc/redis/
if [ -f ../config/redis-openvas.conf ]; then
    cp -v ../config/redis-openvas.conf $INSTALL_ROOT/etc/redis/
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
