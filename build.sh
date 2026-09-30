#!/bin/bash

export ARCH=arm64
export PLATFORM_VERSION=14
export USE_CCACHE=1

TOOLCHAIN="$PWD/toolchain/clang/host/linux-x86/clang-r383902/bin"

export PATH="$TOOLCHAIN:$PATH"

CC_ARG=""

if [ "$USE_CCACHE" = "1" ]; then
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
    CC_ARG='CC="ccache clang"'
else
    CC_ARG='CC="clang"'
fi

echo "CC: $(command -v clang)"
clang --version

if [ "$MAKE_CONFIGURE" = "1" ]; then
  echo "Running make config..."
  make ARCH=arm64 exynos850-a13xx_defconfig
fi

echo "Running build..."
eval make ARCH=arm64 -j"$(nproc)" $CC_ARG

echo "Running publish..."
(
  cd ./Build/
  ./publish.sh
)
