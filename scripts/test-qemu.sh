#!/bin/bash
set -euo pipefail
[[ $# == 1 ]] || { echo 'usage: test-qemu.sh IMAGE (QEMU writes a temporary snapshot)' >&2; exit 1; }
image=$(realpath "$1")
[[ -f $image && $image != *,* ]] || exit 1
code=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}
vars=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$vars" "$work/vars.fd"
qemu-system-x86_64 -machine q35 -m 4096 -smp 4 \
 -drive "if=pflash,format=raw,readonly=on,file=$code" \
 -drive "if=pflash,format=raw,file=$work/vars.fd" \
 -device qemu-xhci -drive "if=none,id=usb,format=raw,snapshot=on,file=$image" \
 -device usb-storage,drive=usb -device virtio-vga \
 -netdev user,id=n -device virtio-net-pci,netdev=n -serial stdio
