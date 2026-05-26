#!/usr/bin/env bash
#
# Build the minix-box Linux image with Buildroot directly on a native Linux host
# (no Docker). For macOS, use ./build.sh instead.
#
# Usage:
#   ./build-native.sh                  full build -> sw/images/
#   ./build-native.sh --defconfig      load the defconfig only (fast sanity check)
#   ./build-native.sh --menuconfig     open Buildroot menuconfig
#   ./build-native.sh --linux-menuconfig   open the kernel menuconfig (to complete linux.config)
#   ./build-native.sh --clean          remove the Buildroot tree + output (keeps download cache)
#
# Buildroot and its output/ go under sw/.build/ (gitignored); artifacts are copied
# to sw/images/. The download cache (sw/.build/dl) persists across --clean.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="${SCRIPT_DIR}/buildroot-external"
OUT_DIR="${SCRIPT_DIR}/images"
WORK_DIR="${SCRIPT_DIR}/.build"
BR_VER="$(cat "${SCRIPT_DIR}/buildroot.version")"
BR_DIR="${WORK_DIR}/buildroot-${BR_VER}"
O_DIR="${WORK_DIR}/output"
export BR2_DL_DIR="${BR2_DL_DIR:-${WORK_DIR}/dl}"

MODE="${1:-build}"

if [ "$(uname -s)" != "Linux" ]; then
	echo "error: native build requires Linux. On macOS use ./build.sh (Docker)." >&2
	exit 1
fi
if [ "$(id -u)" = "0" ]; then
	echo "error: do not run Buildroot as root. Use a normal user account." >&2
	exit 1
fi

if [ "${MODE}" = "--clean" ]; then
	rm -rf "${BR_DIR}" "${O_DIR}"
	echo ">> removed Buildroot tree + output (download cache kept at ${BR2_DL_DIR})"
	exit 0
fi

# Check host build tools.
missing=()
for t in gcc g++ make wget cpio rsync bc unzip python3 perl file which sed; do
	command -v "$t" >/dev/null 2>&1 || missing+=("$t")
done
if [ "${#missing[@]}" -ne 0 ]; then
	echo "error: missing host tools: ${missing[*]}" >&2
	echo "install (Debian/Ubuntu): sudo apt install build-essential wget cpio rsync bc unzip python3 perl file libncurses-dev" >&2
	echo "install (Fedora):         sudo dnf install @development-tools wget cpio rsync bc unzip python3 perl file ncurses-devel" >&2
	echo "install (Arch):           sudo pacman -S base-devel wget cpio rsync bc unzip python perl file ncurses" >&2
	exit 1
fi

mkdir -p "${WORK_DIR}" "${OUT_DIR}" "${BR2_DL_DIR}"

if [ ! -d "${BR_DIR}" ]; then
	echo ">> downloading Buildroot ${BR_VER}"
	wget -q -O "${WORK_DIR}/buildroot-${BR_VER}.tar.gz" \
		"https://buildroot.org/downloads/buildroot-${BR_VER}.tar.gz"
	tar -C "${WORK_DIR}" -xf "${WORK_DIR}/buildroot-${BR_VER}.tar.gz"
	rm -f "${WORK_DIR}/buildroot-${BR_VER}.tar.gz"
fi

make -C "${BR_DIR}" BR2_EXTERNAL="${EXT_DIR}" O="${O_DIR}" minix-box_defconfig

case "${MODE}" in
	--defconfig)
		echo ">> defconfig loaded OK"
		exit 0
		;;
	--menuconfig)
		exec make -C "${BR_DIR}" O="${O_DIR}" menuconfig
		;;
	--linux-menuconfig)
		exec make -C "${BR_DIR}" O="${O_DIR}" linux-menuconfig
		;;
esac

make -C "${BR_DIR}" O="${O_DIR}"

for f in sdcard.img u-boot-sunxi-with-spl.bin zImage; do
	[ -f "${O_DIR}/images/${f}" ] && cp -v "${O_DIR}/images/${f}" "${OUT_DIR}/"
done
cp -v "${O_DIR}/images/"*.dtb "${OUT_DIR}/" 2>/dev/null || true
echo ">> artifacts in sw/images/"
