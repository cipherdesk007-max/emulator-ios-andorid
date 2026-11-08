#!/bin/bash
# FMLAB Emulator: libarchive statica per iPhone (arm64), per aprire i giochi in .zip, .7z e .rar senza estrarli a mano.
# Versione stabile ufficiale (tag). LZMA (7z) dalla libreria di iOS, con le intestazioni
# pubbliche di XZ Utils in ios/terzi/lzma-api (come in FMLAB Linux).
set -euo pipefail
VERSIONE_LA=v3.7.7
qui="$(cd "$(dirname "$0")/.." && pwd)"
out="$qui/../build/libarchive"
[ -f "$out/lib/libarchive.a" ] && { echo "libarchive già pronta"; exit 0; }
tmp="$(mktemp -d)"
git -c advice.detachedHead=false clone -q --depth 1 --branch "$VERSIONE_LA" https://github.com/libarchive/libarchive "$tmp/src"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
cmake -S "$tmp/src" -B "$tmp/b" -G "Unix Makefiles" \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF -DENABLE_TEST=OFF -DENABLE_TAR=OFF -DENABLE_CPIO=OFF -DENABLE_CAT=OFF -DENABLE_UNZIP=OFF \
  -DENABLE_OPENSSL=OFF -DENABLE_MBEDTLS=OFF -DENABLE_NETTLE=OFF -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF \
  -DENABLE_LZ4=OFF -DENABLE_ZSTD=OFF -DENABLE_LIBB2=OFF -DENABLE_ACL=OFF -DENABLE_XATTR=OFF -DENABLE_ICONV=OFF \
  -DENABLE_CNG=OFF -DENABLE_PCREPOSIX=OFF -DENABLE_PCRE2POSIX=OFF -DENABLE_LZO=OFF -DENABLE_WERROR=OFF \
  -DENABLE_ZLIB=ON -DENABLE_BZip2=ON -DENABLE_LZMA=ON \
  -DLIBLZMA_INCLUDE_DIR="$qui/terzi/lzma-api" -DLIBLZMA_LIBRARY="$SDK/usr/lib/liblzma.tbd" \
  -DCMAKE_C_FLAGS="-Wno-error" >"$tmp/cmake.log" 2>&1 || { tail -60 "$tmp/cmake.log"; exit 1; }
grep -E "LZMA|BZIP2|ZLIB" "$tmp/b/config.h" | grep -E "define HAVE_(LZMA_H|BZLIB_H|ZLIB_H|LIBLZMA|LIBBZ2|LIBZ) " || true
cmake --build "$tmp/b" --target archive_static -j "$(sysctl -n hw.ncpu)" >"$tmp/build.log" 2>&1 || { grep -E "error" "$tmp/build.log" | head -40; tail -30 "$tmp/build.log"; exit 1; }
mkdir -p "$out/lib" "$out/include"
cp "$tmp/b/libarchive/libarchive.a" "$out/lib/"
cp "$tmp/src/libarchive/archive.h" "$tmp/src/libarchive/archive_entry.h" "$out/include/"
echo "libarchive pronta: $(du -h "$out/lib/libarchive.a" | cut -f1)"
