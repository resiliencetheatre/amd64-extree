#!/bin/bash
# Configuration and source checks only: no target packages or images are built.
set -euo pipefail
ext=$(cd -- "$(dirname -- "$0")/.." && pwd)
br=$(realpath "${BUILDROOT_DIR:-$ext/../buildroot}")
out=$(realpath -m "${CHECK_OUTPUT_DIR:-$ext/../output-amd64-check}")
[[ $(git -C "$br" rev-parse HEAD) == "$(cat "$ext/BUILDROOT_REVISION")" ]]
make -C "$br" O="$out" BR2_EXTERNAL="$ext" amd64_usb_live_defconfig
python3 - "$ext/configs/amd64_usb_live_defconfig" "$out/.config" <<'PY'
import pathlib, sys
requested = pathlib.Path(sys.argv[1]).read_text().splitlines()
actual = set(pathlib.Path(sys.argv[2]).read_text().splitlines())
assert 'BR2_TARGET_GENERIC_ROOT_PASSWD="root"' in actual
missing = [x for x in requested if x.startswith('BR2_') and x not in actual]
assert not missing, missing
for symbol in ('BR2_PACKAGE_LIBFIDO2', 'BR2_PACKAGE_LIBCBOR', 'BR2_PACKAGE_PCSC_LITE', 'BR2_PACKAGE_CCID', 'BR2_PACKAGE_OPENSC', 'BR2_PACKAGE_P11_KIT', 'BR2_PACKAGE_EXFATPROGS', 'BR2_PACKAGE_NTFS_3G_NTFSPROGS', 'BR2_PACKAGE_DOSFSTOOLS_FSCK_FAT', 'BR2_TOOLCHAIN_BUILDROOT_GLIBC', 'BR2_SHARED_LIBS', 'BR2_INSTALL_LIBSTDCPP', 'BR2_PACKAGE_LIBGLVND', 'BR2_PACKAGE_LIBGLVND_DISPATCH_EGL', 'BR2_PACKAGE_LIBGLVND_DISPATCH_GLES', 'BR2_PACKAGE_GPTFDISK_SGDISK', 'BR2_PACKAGE_UTIL_LINUX_PARTX', 'BR2_PACKAGE_UTIL_LINUX_WIPEFS', 'BR2_PACKAGE_PROCPS_NG', 'BR2_PACKAGE_ALSA_UTILS_APLAY', 'BR2_PACKAGE_ALSA_UTILS_ALSAMIXER', 'BR2_PACKAGE_IWD', 'BR2_PACKAGE_READLINE', 'BR2_PACKAGE_WIRELESS_REGDB', 'BR2_PACKAGE_WESTON', 'BR2_PACKAGE_WEBKITGTK_MINIBROWSER', 'BR2_PACKAGE_WEBKITGTK_SANDBOX', 'BR2_PACKAGE_SYSTEMD_LOGIND', 'BR2_PACKAGE_LINUX_PAM', 'BR2_PACKAGE_LIBARGON2', 'BR2_PACKAGE_DROPBEAR', 'BR2_TARGET_ENABLE_ROOT_LOGIN'):
    assert symbol + '=y' in actual, symbol
for symbol in ('BR2_PACKAGE_PULSEAUDIO', 'BR2_PACKAGE_PIPEWIRE', 'BR2_PACKAGE_WPA_SUPPLICANT', 'BR2_PACKAGE_XORG7', 'BR2_PACKAGE_XWAYLAND', 'BR2_PACKAGE_DROPBEAR_CLIENT', 'BR2_PACKAGE_OPENSSH', 'BR2_PACKAGE_SEATD_DAEMON', 'BR2_PACKAGE_SEATD_BUILTIN', 'BR2_LEGACY'):
    assert symbol + '=y' not in actual, symbol
PY
make -C "$br" O="$out" BR2_EXTERNAL="$ext" olddefconfig
make -C "$br" O="$out" BR2_EXTERNAL="$ext" savedefconfig BR2_DEFCONFIG="$out/roundtrip_defconfig"
cmp "$ext/configs/amd64_usb_live_defconfig" "$out/roundtrip_defconfig"
"$br/support/scripts/check-merged" -t overlay -u -b "$ext/board/amd64-usb-live/rootfs-overlay"
while IFS= read -r -d '' file; do
 case "$(head -1 "$file")" in '#!/bin/bash'*) bash -n "$file";; '#!/bin/sh'*) sh -n "$file";; esac
done < <(find "$ext" -name .git -prune -o -type f ! -name '*.png' -print0)
python3 - "$ext/scripts/copy-elf-libs.py" <<'PY'
import ast, pathlib, sys
ast.parse(pathlib.Path(sys.argv[1]).read_text())
PY
printf 'Configuration round trip, required/forbidden options, overlay layout and syntax checks passed.\n'
