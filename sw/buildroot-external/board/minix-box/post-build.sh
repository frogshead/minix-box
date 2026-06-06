#!/bin/sh
# minix-box rootfs post-build tweaks. Runs with $TARGET_DIR as the rootfs.
# Console getty + hostname + root password come from the Buildroot defconfig;
# add any extra rootfs fixups here as the project grows.
set -e

# Force "minix" user to change password at first login.
sed -i 's/^minix:\([^:]*\):[^:]*/minix:\1:0/' "$TARGET_DIR/etc/shadow"
