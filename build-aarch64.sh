#!/usr/bin/env bash
# Cross-builds the `play` executable for aarch64 handhelds (ArkOS4Clones, other PortMaster firmwares) on an x86_64 Linux host.
#
# zig is the C / C++ compiler: it can target an old glibc (default 2.30, the one ArkOS ships) from any host, with no emulation
# and no Docker. Host packages (Debian / Ubuntu):
#   sudo apt-get install cmake ninja-build pkg-config curl xz-utils zip binutils \
#        libdrm-dev libgbm-dev libasound2-dev libudev-dev libegl-dev
# (only their HEADERS are used: SDL loads the aarch64 libraries on the device at run time.)
#
# Environment: ZIG_VERSION (0.13.0), ZIG_SHA256 (verify the download), GLIBC (2.30), JOBS, WORK, OUT, CMAKE_EXTRA_ARGS
# (extra cmake options, e.g. to change an SDL driver).
# Result: portmaster/out/play. Then run portmaster/package.sh.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$ROOT/portmaster/work}
OUT=${OUT:-$ROOT/portmaster/out}
ZIG_VERSION=${ZIG_VERSION:-0.13.0}
GLIBC=${GLIBC:-2.30}
JOBS=${JOBS:-$(nproc)}

die() { echo "error: $*" >&2; exit 1; }

mkdir -p "$WORK/bin" "$OUT"

# --- zig -------------------------------------------------------------------------------------------------------------
if command -v zig >/dev/null 2>&1; then
  ZIG=$(command -v zig)
else
  ZIG_DIR=$WORK/zig-linux-x86_64-$ZIG_VERSION
  if [ ! -x "$ZIG_DIR/zig" ]; then
    echo ">> downloading zig $ZIG_VERSION"
    curl -fL "https://ziglang.org/download/$ZIG_VERSION/zig-linux-x86_64-$ZIG_VERSION.tar.xz" -o "$WORK/zig.tar.xz"
    sum=$(sha256sum "$WORK/zig.tar.xz" | cut -d' ' -f1)
    echo "   sha256 $sum"
    if [ -n "${ZIG_SHA256:-}" ] && [ "$sum" != "$ZIG_SHA256" ]; then die "zig download does not match ZIG_SHA256"; fi
    tar -xf "$WORK/zig.tar.xz" -C "$WORK"
  fi
  ZIG=$ZIG_DIR/zig
fi
echo ">> zig $("$ZIG" version), target aarch64-linux-gnu.$GLIBC"

# --- compiler wrappers (CMake wants single executables) ----------------------------------------------------------------
write_wrapper() {  # name, zig subcommand
  printf '#!/bin/sh\nexec "%s" %s -target aarch64-linux-gnu.%s -fno-sanitize=undefined "$@"\n' "$ZIG" "$2" "$GLIBC" >"$WORK/bin/$1"
  chmod +x "$WORK/bin/$1"
}
write_wrapper aarch64-cc cc
write_wrapper aarch64-c++ c++
printf '#!/bin/sh\nexec "%s" ar "$@"\n' "$ZIG" >"$WORK/bin/aarch64-ar"
printf '#!/bin/sh\nexec "%s" ranlib "$@"\n' "$ZIG" >"$WORK/bin/aarch64-ranlib"
chmod +x "$WORK/bin/aarch64-ar" "$WORK/bin/aarch64-ranlib"
export HOTD2_ZIG_BIN=$WORK/bin
export ZIG_GLOBAL_CACHE_DIR=${ZIG_GLOBAL_CACHE_DIR:-$WORK/zig-cache}
export ZIG_LOCAL_CACHE_DIR=${ZIG_LOCAL_CACHE_DIR:-$WORK/zig-cache}

# --- configure + build -------------------------------------------------------------------------------------------------
# SDL: KMS/DRM video + EGL / OpenGL ES (libmali exposes both through gbm), ALSA audio, evdev input; everything loaded with
# dlopen. No X11 / Wayland / Vulkan / PulseAudio: they are not on these devices, and SDL_GPU (Vulkan) is not used here.
cmake -S "$ROOT" -B "$WORK/build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ROOT/portmaster/toolchain-aarch64-zig.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS=-s \
  -DHOTD2_ALLOW_64BIT=ON -DHOTD2_GLES=ON -DHOTD2_SDL_GPU=OFF \
  -DSDL_KMSDRM=ON -DSDL_KMSDRM_SHARED=ON -DSDL_OPENGLES=ON -DSDL_OPENGL=OFF -DSDL_VULKAN=OFF \
  -DSDL_X11=OFF -DSDL_WAYLAND=OFF \
  -DSDL_ALSA=ON -DSDL_ALSA_SHARED=ON -DSDL_PULSEAUDIO=OFF -DSDL_PIPEWIRE=OFF -DSDL_JACK=OFF -DSDL_SNDIO=OFF \
  -DSDL_LIBUDEV=ON -DSDL_DBUS=OFF -DSDL_IBUS=OFF -DSDL_HIDAPI=OFF -DSDL_CAMERA=OFF \
  ${CMAKE_EXTRA_ARGS:-}
cmake --build "$WORK/build" --target play --parallel "$JOBS"

# --- checks ------------------------------------------------------------------------------------------------------------
BIN=$WORK/build/src/port/play
[ -f "$BIN" ] || die "the build did not produce $BIN"
readelf -h "$BIN" | grep -q 'AArch64' || die "$BIN is not an aarch64 executable"

# The highest GLIBC_x.y symbol version the binary needs must not exceed the device's glibc.
need=$(readelf --dyn-syms -W "$BIN" | grep -o 'GLIBC_[0-9][0-9.]*' | sed 's/^GLIBC_//' | sort -V | tail -1)
echo ">> highest glibc symbol version needed: ${need:-none} (device limit $GLIBC)"
if [ -n "$need" ] && [ "$(printf '%s\n%s\n' "$need" "$GLIBC" | sort -V | tail -1)" != "$GLIBC" ]; then
  die "the binary needs glibc $need, newer than $GLIBC"
fi
echo ">> shared libraries it asks for:"
readelf -d "$BIN" | grep NEEDED || true

cp "$BIN" "$OUT/play"
echo ">> $OUT/play ready"
