#!/usr/bin/env bash
# Assembles the PortMaster package (portmaster/out/hotd2-portmaster.zip) around the aarch64 `play` built by build-aarch64.sh.
#
# The package carries the launcher, the controller mapping, the repository's scene files and the program. It does NOT carry
# the game data (Sega's): the player copies the `game` folder of the Windows release into hotd2/game on the device.
#
# Environment: OUT (portmaster/out), PLAY (the executable, default $OUT/play), ALLOW_ANY_ARCH=1 (skip the aarch64 check;
# only for testing the packaging with a host binary).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$ROOT/portmaster/out}
PLAY=${PLAY:-$OUT/play}
PM=$ROOT/portmaster

die() { echo "error: $*" >&2; exit 1; }

[ -f "$PLAY" ] || die "no executable at $PLAY (run portmaster/build-aarch64.sh first)"
if [ -z "${ALLOW_ANY_ARCH:-}" ]; then
  readelf -h "$PLAY" | grep -q 'AArch64' || die "$PLAY is not an aarch64 executable"
fi
[ -d "$ROOT/scenes" ] || die "no scenes directory in $ROOT"

PKG=$OUT/pkg
rm -rf "$PKG"
mkdir -p "$PKG/hotd2/game"
install -m 755 "$PM/HOTD2.sh" "$PKG/HOTD2.sh"
install -m 755 "$PLAY" "$PKG/hotd2/play"
install -m 644 "$PM/hotd2.gptk" "$PM/port.json" "$PKG/hotd2/"
install -m 644 "$PM/README.md" "$PKG/hotd2/README.md"
cp -r "$ROOT/scenes" "$PKG/hotd2/scenes"
cat >"$PKG/hotd2/game/PUT-GAME-FILES-HERE.txt" <<'EOF'
Copy the contents of the "game" folder of the HOTD2RE Windows release here, so that this folder contains Hod2.exe,
cam/, coli/, evt/, mot/, pol/, Sound/ and tex/. See ../README.md.
EOF

rm -f "$OUT/hotd2-portmaster.zip"
(cd "$PKG" && zip -qr "$OUT/hotd2-portmaster.zip" HOTD2.sh hotd2)
echo ">> $OUT/hotd2-portmaster.zip"
unzip -l "$OUT/hotd2-portmaster.zip" | tail -n +4 | head -n 12
