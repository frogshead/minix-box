#!/bin/sh
# Assemble the SD-card image with genimage. Run by Buildroot after the build
# (CWD = Buildroot main dir; BINARIES_DIR etc. are exported in the environment).
set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"

support/scripts/genimage.sh -c "${GENIMAGE_CFG}"
