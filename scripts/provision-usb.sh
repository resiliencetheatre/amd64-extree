#!/bin/bash
# Explicitly destructive host operation. No disk is selected automatically.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
fail() { echo "Provision: $*" >&2; exit 1; }
[[ $EUID == 0 && $# -ge 2 && $# -le 3 ]] || fail 'usage: sudo provision-usb.sh IMAGE WHOLE_DEVICE [--data]'
image=$(realpath "$1"); disk=$(realpath "$2"); data=${3:-}
[[ -z $data || $data == --data ]] || fail 'unknown option'
[[ -f $image && -b $disk ]] || fail 'image and explicit block device required'
for tool in flock lsblk findmnt swapon sgdisk partprobe udevadm blkid blockdev dd mount umount; do command -v "$tool" >/dev/null || fail "missing $tool"; done
if [[ -n $data ]]; then
 for tool in cryptsetup mkfs.ext4; do command -v "$tool" >/dev/null || fail "missing $tool"; done
fi
type=$(lsblk -dnro TYPE "$disk")
[[ $type == disk || $type == loop ]] || fail 'target must be a whole disk or disposable loop device'
[[ $(blockdev --getro "$disk") == 0 ]] || fail 'read-only disk'
[[ $(blockdev --getss "$disk") == 512 ]] || fail 'this image requires 512-byte logical sectors'
# Require removable/USB transport; loop devices are explicitly supported for tests.
[[ $type == loop || $(lsblk -dnro TRAN "$disk") == usb || $(lsblk -dnro RM "$disk") == 1 ]] || fail 'refusing non-USB, non-removable physical disk'
check_idle() {
 local node source mountpath mm
 while read -r node; do
  mm=$(lsblk -dnro MAJ:MIN "$node")
  ! findmnt -rn -o MAJ:MIN | grep -Fxq "$mm" || fail "mounted target: $node"
  [[ -z $(ls -A "/sys/class/block/$(basename "$node")/holders") ]] || fail "active holders: $node"
  while read -r source; do
   [[ -z $source ]] && continue
   if [[ -b $source ]]; then
    ! lsblk -snrpo NAME "$source" | grep -Fxq "$disk" || fail 'active swap on target'
   else
    source=$(findmnt -nro SOURCE -T "$source")
    ! lsblk -snrpo NAME "$source" 2>/dev/null | grep -Fxq "$disk" || fail 'swap file on target'
   fi
  done < <(swapon --noheadings --raw --show=NAME)
 done < <(lsblk -nrpo NAME "$disk")
 for mountpath in / /boot /boot/efi; do
  source=$(findmnt -nro SOURCE -T "$mountpath")
  [[ $source != /dev/* ]] || { ! lsblk -snrpo NAME "$source" | grep -Fxq "$disk" || fail 'running root/boot disk'; }
 done
}
exec 9<"$disk"
flock -n -x 9 || fail "another provisioner is using this disk"
check_idle
bytes=$(stat -c %s "$image")
extra=$((2*1024*1024)); [[ -z $data ]] || extra=$((512*1024*1024))
(( $(blockdev --getsize64 "$disk") >= bytes+extra )) || fail 'insufficient capacity'
# Check image structure before any write.
sgdisk -v "$image"
[[ $(sgdisk -p "$image" | awk '$1 ~ /^[0-9]+$/ {n++} END {print n}') == 2 ]] || fail 'expected two-partition live image'
lsblk -o NAME,TYPE,SIZE,MODEL,SERIAL,TRAN,MOUNTPOINTS "$disk"
printf 'ALL CONTENTS WILL BE LOST. Type "ERASE %s": ' "$disk" >/dev/tty
read -r confirmation </dev/tty
[[ $confirmation == "ERASE $disk" ]] || fail 'cancelled'
check_idle
dd if="$image" of="$disk" bs=4M conv=fsync status=progress
sgdisk -e "$disk"
# Unique disk and partition GUIDs, including no-data USBs.
sgdisk -G "$disk"
if [[ -n $data ]]; then sgdisk -n 3:0:0 -t 3:8309 -c 3:live-data "$disk"; fi
partprobe "$disk"
udevadm settle
partition() { lsblk -nrpo NAME,PARTN "$disk" | awk -v n="$1" '$2 == n {print $1}'; }
efi=$(partition 1); root=$(partition 2)
[[ -b $efi && -b $root ]] || fail 'partitions not visible; stop and inspect manually'
work=$(mktemp -d /tmp/amd64-provision.XXXXXX)
mapper=amd64-provision-$$
mapped=0
cleanup() {
 mountpoint -q "$work/data" && umount "$work/data"
 mountpoint -q "$work/efi" && umount "$work/efi"
 if [[ $mapped == 1 ]]; then cryptsetup close "$mapper"; fi
 rmdir "$work/data" "$work/efi" "$work" 2>/dev/null || true
}
trap cleanup EXIT
mkdir "$work/efi" "$work/data"
mount -t vfat -o nosuid,nodev,noexec "$efi" "$work/efi"
rootid=$(blkid -s PARTUUID -o value "$root")
sed -i -E "s/live.root=[0-9a-f-]+/live.root=$rootid/g" "$work/efi/EFI/BOOT/grub.cfg"
rm -f "$work/efi/live-data.conf"
if [[ -n $data ]]; then
 part=$(partition 3); [[ -b $part ]] || fail 'data partition missing'
 cryptsetup luksFormat --type luks2 "$part" </dev/tty
 cryptsetup open "$part" "$mapper" </dev/tty
 mapped=1
 mkfs.ext4 -L live-data "/dev/mapper/$mapper"
 mount -o nosuid,nodev "/dev/mapper/$mapper" "$work/data"
 mkdir -p "$work/data/tech/Documents"
 chown -R 1000:1000 "$work/data/tech"
 chmod 0700 "$work/data/tech"
 umount "$work/data"
 cryptsetup close "$mapper"; mapped=0
 printf 'ROOT_PARTUUID=%s\nDATA_PARTUUID=%s\nLUKS_UUID=%s\n' "$rootid" "$(blkid -s PARTUUID -o value "$part")" "$(cryptsetup luksUUID "$part")" >"$work/efi/live-data.conf"
fi
sync
umount "$work/efi"
echo 'Provisioning finished. No firmware boot entries were written.'
