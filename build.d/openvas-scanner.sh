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
make #-j$(nproc)
make install
# install rust to build openvasd and scannerctl
cd ..
#export RUST_BACKTRACE=full
#export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true
curl -o rustup.sh https://sh.rustup.rs
bash ./rustup.sh -y
. "$HOME/.cargo/env"

# Pre-fetch cargo registry if crates.tar exists
cd rust
if [ -f /rust/crates.tar ]; then
    echo "Using pre-fetched crate cache"
    tar xvf /rust/crates.tar
fi

# Build openvasd
cd src/openvasd
cargo fetch --locked
if [ -f /rust/crates.tar ]; then
    cargo build --frozen --release -vv
else
    cargo build --release -vv
fi

cd ../scannerctl
cargo fetch --locked
if [ -f /rust/crates.tar ]; then
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
