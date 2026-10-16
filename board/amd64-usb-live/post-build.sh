#!/bin/sh
set -eu
target=$1
mkdir -p "$target/data" "$target/etc/systemd/system/graphical.target.wants" "$target/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/graphical.target "$target/etc/systemd/system/default.target"
ln -sf ../live-weston.service "$target/etc/systemd/system/graphical.target.wants/live-weston.service"
ln -sf ../live-data-cleanup.service "$target/etc/systemd/system/multi-user.target.wants/live-data-cleanup.service"
# Explicitly enable the requested temporary remote debugging service.
if grep -q '^BR2_PACKAGE_DROPBEAR=y$' "$BR2_CONFIG"; then
 ln -sf /usr/lib/systemd/system/dropbear.service "$target/etc/systemd/system/multi-user.target.wants/dropbear.service"
fi
ln -sf ../live-persistence.service "$target/etc/systemd/system/multi-user.target.wants/live-persistence.service"
for unit in systemd-networkd systemd-resolved systemd-timesyncd iwd alsa-restore; do
 ln -sf "/usr/lib/systemd/system/$unit.service" "$target/etc/systemd/system/multi-user.target.wants/$unit.service"
done
for unit in systemd-networkd-wait-online.service systemd-gpt-auto-generator systemd-hibernate-resume-generator; do
 case "$unit" in *generator) mkdir -p "$target/etc/systemd/system-generators"; ln -sf /dev/null "$target/etc/systemd/system-generators/$unit";;
 *) ln -sf /dev/null "$target/etc/systemd/system/$unit";; esac
done
ln -sf /run/systemd/resolve/stub-resolv.conf "$target/etc/resolv.conf"
: >"$target/etc/machine-id"
# No root/data/EFI mounts or swap entries are generated from local disks.
printf 'tmpfs /tmp tmpfs mode=1777,nosuid,nodev 0 0\n' >"$target/etc/fstab"
chmod 0440 "$target/etc/sudoers.d/live-data"
# libepoxy opens desktop OpenGL dynamically; ELF dependencies do not capture it.
test -e "$target/usr/lib/libOpenGL.so.0"
test -x "$target/usr/bin/MiniBrowser"
test -x "$target/usr/bin/weston-terminal"
# First-boot provisioning must never discover a missing tool after modifying GPT.
for tool in sgdisk partx wipefs lsblk findmnt flock blockdev cryptsetup mkfs.ext4 pgrep; do
 test -x "$target/usr/bin/$tool" || test -x "$target/usr/sbin/$tool" || {
  echo "Missing persistence tool: $tool" >&2
  echo "After changing package options, reconfigure the existing package before rebuilding." >&2
  echo "For partx/wipefs: make util-linux-reconfigure (with your usual BR2_EXTERNAL and O, if used)." >&2
  exit 1;
 }
done
# Verify source-level CLI contracts against the actual downloaded versions.
# This does not run cross-compiled executables on the build host.
python3 - "$BUILD_DIR" <<'PY'
import pathlib, re, sys
build = pathlib.Path(sys.argv[1])
terminals = list((build / 'weston-16.0.0').rglob('terminal.c'))
assert terminals, 'Weston terminal source not found'
assert any(re.search(r'WESTON_OPTION_STRING\s*,\s*"shell"', p.read_text()) for p in terminals), 'Verify weston-terminal --shell before shipping'
source = (build / 'webkitgtk-2.52.4/Tools/MiniBrowser/gtk/main.c').read_text()
assert 'g_get_user_data_dir()' in source and 'g_get_user_cache_dir()' in source, 'Verify MiniBrowser XDG profile paths before shipping'
PY
