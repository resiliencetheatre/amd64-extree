#!/bin/bash
set -euo pipefail
ext=$(cd -- "$(dirname -- "$0")/.." && pwd)
br=$(realpath "${BUILDROOT_DIR:-$ext/../buildroot}")
out=$(realpath -m "${OUTPUT_DIR:-$ext/../output-amd64}")
[[ $EUID != 0 ]] || { echo 'Run Buildroot as an ordinary user.' >&2; exit 1; }
[[ $(git -C "$br" rev-parse HEAD) == "$(cat "$ext/BUILDROOT_REVISION")" ]] || { echo 'Buildroot revision mismatch' >&2; exit 1; }
[[ -z $(git -C "$br" status --porcelain --untracked-files=no) ]] || { echo 'Buildroot tracked files are modified' >&2; exit 1; }
if [[ ! -f $out/.config ]]; then make -C "$br" O="$out" BR2_EXTERNAL="$ext" amd64_usb_live_defconfig; fi
exec make -C "$br" O="$out" BR2_EXTERNAL="$ext" "$@"
