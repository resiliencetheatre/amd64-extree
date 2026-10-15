#!/bin/bash
set -euo pipefail
export LC_ALL=C
board=$(cd -- "$(dirname -- "$0")" && pwd)
export PATH="$HOST_DIR/bin:$HOST_DIR/sbin:$PATH"
work="$BUILD_DIR/amd64-boot-initramfs"
rm -rf -- "$work"
mkdir -p "$work"/{bin,sbin,lib,dev,proc,sys,run,newroot}
# The amd64 glibc loader searches /lib64; dependencies are copied to /lib.
ln -s lib "$work/lib64"
cp "$TARGET_DIR/bin/busybox" "$work/bin/"
for app in sh mount umount switch_root sleep mkdir cat; do ln -s busybox "$work/bin/$app"; done
cp "$TARGET_DIR/usr/bin/blkid" "$work/bin/blkid"
# Copy exactly the ELF dependency closure without executing target binaries.
python3 "$board/../../scripts/copy-elf-libs.py" "$TARGET_DIR" "$work" "$work/bin/busybox"
python3 "$board/../../scripts/copy-elf-libs.py" "$TARGET_DIR" "$work" "$work/bin/blkid"
python3 "$board/../../scripts/check-initramfs.py" "$work"
cp "$board/initramfs/init" "$work/init"
(cd "$work"; find . -print0 | LC_ALL=C sort -z | cpio --null -o -H newc --owner=0:0) | gzip -n >"$BINARIES_DIR/boot-initramfs.cpio.gz"
root_uuid=$(cat /proc/sys/kernel/random/uuid)
boot_uuid=$(cat /proc/sys/kernel/random/uuid)
sed "s/@ROOT_UUID@/$root_uuid/g" "$board/grub.cfg" >"$BINARIES_DIR/efi-part/EFI/BOOT/grub.cfg"
sed -e "s/@ROOT_UUID@/$root_uuid/g" -e "s/@BOOT_UUID@/$boot_uuid/g" "$board/genimage.cfg" >"$BINARIES_DIR/genimage.cfg"
genimage --rootpath "$TARGET_DIR" --tmppath "$BUILD_DIR/genimage-amd64" --inputpath "$BINARIES_DIR" --outputpath "$BINARIES_DIR" --config "$BINARIES_DIR/genimage.cfg"
cp "$BR2_CONFIG" "$BINARIES_DIR/build.config"
{ cat "$board/../../BUILDROOT_REVISION"; sha256sum "$BINARIES_DIR/usb-live.img"; stat -c '%n %s bytes' "$BINARIES_DIR/"{usb-live.img,rootfs.squashfs,bzImage,boot-initramfs.cpio.gz}; } >"$BINARIES_DIR/build-manifest.txt"
