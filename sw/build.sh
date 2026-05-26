#!/usr/bin/env bash
#
# Build the minix-box Linux image with Buildroot inside Docker.
#
# Usage:
#   ./build.sh               full build  -> sw/images/{sdcard.img,u-boot-...,zImage,*.dtb}
#   ./build.sh --defconfig   load the defconfig only (fast sanity check, no compile)
#   ./build.sh --shell       interactive shell in the build container
#   ./build.sh --clean       remove the Buildroot work volume (keeps download cache)
#
# The Buildroot tree and its output/ live in a Docker named volume (Linux ext4),
# which sidesteps macOS's case-insensitive filesystem. Only the final artifacts
# are copied out to sw/images/ on the host.
set -euo pipefail

# Pinned Buildroot version (shared with build-native.sh). Bump in buildroot.version.
BUILDROOT_VERSION="$(cat "$(dirname "${BASH_SOURCE[0]}")/buildroot.version")"

IMAGE="minix-box-builder"
BUILD_VOL="minixbox-buildroot"   # Buildroot source tree + output/
DL_VOL="minixbox-dl"             # Buildroot download cache (persists across cleans)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="${SCRIPT_DIR}/buildroot-external"
OUT_DIR="${SCRIPT_DIR}/images"
MODE="${1:-build}"

if [ "${MODE}" = "--clean" ]; then
	docker volume rm -f "${BUILD_VOL}"
	echo ">> removed ${BUILD_VOL} (download cache ${DL_VOL} kept)"
	exit 0
fi

mkdir -p "${OUT_DIR}"

echo ">> building builder image (${IMAGE})"
docker build -t "${IMAGE}" \
	--build-arg UID="$(id -u)" --build-arg GID="$(id -g)" \
	"${SCRIPT_DIR}"

if [ "${MODE}" = "--shell" ]; then
	exec docker run --rm -it \
		-v "${BUILD_VOL}:/build" -v "${DL_VOL}:/dl" \
		-v "${EXT_DIR}:/ext:ro" -v "${OUT_DIR}:/out" \
		"${IMAGE}" bash
fi

INNER='
set -euo pipefail
export BR2_DL_DIR=/dl
cd /build
if [ ! -d "buildroot-${BR_VER}" ]; then
	echo ">> downloading Buildroot ${BR_VER}"
	wget -q "https://buildroot.org/downloads/buildroot-${BR_VER}.tar.gz"
	tar xf "buildroot-${BR_VER}.tar.gz"
	rm -f "buildroot-${BR_VER}.tar.gz"
fi
cd "buildroot-${BR_VER}"
make BR2_EXTERNAL=/ext O=/build/output minix-box_defconfig
if [ "${MODE}" = "--defconfig" ]; then
	echo ">> defconfig loaded OK"
	exit 0
fi
make O=/build/output
mkdir -p /out
for f in sdcard.img u-boot-sunxi-with-spl.bin zImage; do
	[ -f "/build/output/images/${f}" ] && cp -v "/build/output/images/${f}" /out/
done
cp -v /build/output/images/*.dtb /out/ 2>/dev/null || true
echo ">> artifacts in sw/images/"
'

docker run --rm -t \
	-e BR_VER="${BUILDROOT_VERSION}" -e MODE="${MODE}" \
	-v "${BUILD_VOL}:/build" -v "${DL_VOL}:/dl" \
	-v "${EXT_DIR}:/ext:ro" -v "${OUT_DIR}:/out" \
	"${IMAGE}" bash -c "${INNER}"
