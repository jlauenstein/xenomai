#!/bin/bash
#
# Copyright (c) Siemens AG, 2014-2018

set -x
# set -e

# KRNL_CFGS="noipipe ipipe"

# build kernel for $TARGET arch, $1: kernel config
build_kernel()
{
    echo "=========== $TARGET/$1 build ==========="

    cp ci/conf.${TARGET}.${1} ci/ipipe/.config
    pushd ci/ipipe

    make ARCH=$TARGET CROSS_COMPILE=$CROSS_COMPILE olddefconfig

    make ARCH=$TARGET CROSS_COMPILE=$CROSS_COMPILE -j `nproc` bzImage modules
    
    ls -l .config vmlinux
    make -s ARCH=$TARGET CROSS_COMPILE=$CROSS_COMPILE clean
    popd
}

# build Xenomai user space, use all supplied extra args for configure
build_xeno()
{
    ./scripts/bootstrap
    mkdir ../xenobuild
    pushd ../xenobuild
    ../xenomai/configure --with-core=cobalt --enable-smp "$@"
    make -s -j `nproc` all
    popd
}

################################################################

case $TARGET in
    x86)
        XENO_ARCH=x86
        XENO_OPTS="--enable-pshared"
        ;;
    i386)
        sudo apt-get install -qq --no-install-recommends gcc-multilib >/dev/null
        XENO_ARCH=x86
        XENO_OPTS=("--enable-pshared" "--host=i686-linux" "CFLAGS=-m32 -O2" "LDFLAGS=-m32")
        ;;
    arm)
        sudo apt-get install -qq gcc-arm-linux-gnueabihf >/dev/null
        CROSS_COMPILE=arm-linux-gnueabihf-
        XENO_ARCH=arm
        XENO_OPTS=("--build=i686-pc-linux-gnu" "--host=arm-linux-gnueabihf" "CC=arm-linux-gnueabihf-gcc" \
                   "CFLAGS=-march=armv7-a -mfpu=vfp3" "LDFLAGS=-march=armv7-a -mfpu=vfp3")
        ;;
    *)
        echo "===== Error TARGET: $TARGET ====="
        exit 1
        ;;
esac


build_kernel "noipipe"

build_kernel "ipipe"

./scripts/prepare-kernel.sh --arch=$XENO_ARCH --verbose --linux=ci/ipipe

build_kernel "xeno"

build_xeno "${XENO_OPTS[@]}"

exit 0
