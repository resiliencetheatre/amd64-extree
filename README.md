# AMD64 USB live desktop

This BR2_EXTERNAL tree targets the sibling `../buildroot` checkout at
`acbcc911b71f93bb7ea9400aa19713f3464c8e69` (2026.11-git). It is independent
of the Raspberry Pi configurations. Upstream files remain unmodified.
**Baseline 1 (2026-10-15): manually built and booted by the user on a Dell
Latitude 7280.** Weston, touchpad, terminal, Nano, Midnight Commander and
MiniBrowser work. See [BASELINE.md](BASELINE.md) for the recorded image identity
and scope, and [VALIDATION.md](VALIDATION.md) for remaining acceptance work.

LLVM 23 libclc compatibility settings live in `support/libclc.mk`; see
`support/README.md` for the host-libclc GCC/OpenCL failure and retry commands.

## Build manually

Run as an ordinary user from `/home/tech/laboratory/amd64` (or the equivalent
parent directory after relocating both trees):

```sh
make -C buildroot O="$PWD/output-amd64" \
  BR2_EXTERNAL="$PWD/amd64-extree" amd64_usb_live_defconfig
make -C buildroot O="$PWD/output-amd64" BR2_EXTERNAL="$PWD/amd64-extree" BR2_JLEVEL=2
make -C buildroot O="$PWD/output-amd64" BR2_EXTERNAL="$PWD/amd64-extree" \
  savedefconfig BR2_DEFCONFIG="$PWD/amd64-extree/configs/amd64_usb_live_defconfig"
```

The existing baseline was built in-tree, with configuration `buildroot/.config`
and output `buildroot/output`. To continue that build from the parent directory:

```sh
make -C buildroot BR2_EXTERNAL="$PWD/amd64-extree" BR2_JLEVEL=2
```

Do not add `O=` when continuing this existing build. The separate-output commands
above are for a fresh build checkout; do not mix the two layouts. `BR2_JLEVEL=2`
limits package parallelism on the 32 GB host; use 1 if WebKit still exhausts RAM.

Alternatively, `amd64-extree/scripts/build.sh` checks the revision, initializes
an absent configuration, then builds. Set `BUILDROOT_DIR` and `OUTPUT_DIR`
for other locations. Extra arguments are make targets, for example
`amd64-extree/scripts/build.sh menuconfig`. It refuses root and a modified
upstream checkout. It preserves an existing output configuration; use the
explicit defconfig command to reset it. Do not reuse another target's output.

A Linux build host needs Buildroot's normal prerequisites: GCC/G++, make,
binutils, bash, patch, perl, Python 3, git, rsync, tar, cpio, gzip, bzip2, xz,
unzip, wget, file, bc, an English UTF-8 locale, and ncurses development files
for menuconfig. SSL/libelf build dependencies are selected as host packages.
Use a case-sensitive filesystem. WebKit, LLVM and Mesa are substantial builds;
allow ample RAM and disk space and reduce `BR2_JLEVEL` if memory is tight.
Downloads require network access; package versions and hashes come from the
pinned checkout. `PACKAGE_VERSIONS.txt` records the selected package versions.
Do not build with sudo. Output/downloads belong outside this source tree.

`amd64-extree/scripts/check.sh` regenerates and round-trips the configuration
in `output-amd64-check`, checks required/forbidden selections, shell/Python
syntax and merged-/usr compatibility. It only compiles Buildroot's host
configuration utility; it does not build target software or an image.

## Image and boot sequence

The output is `output-amd64/images/usb-live.img`, a GPT disk with a 256 MiB
FAT32 EFI partition and a read-only SquashFS system partition. GRUB lives at
`EFI/BOOT/BOOTX64.EFI`; no NVRAM registration or installer is used. Disable
Secure Boot and select the USB in the firmware boot menu. Legacy BIOS is not
supported. The image uses 512-byte logical sectors.

Buildroot builds the kernel and desktop root independently. After SquashFS
creation, post-image assembles a small initramfs from the already-built
BusyBox, util-linux blkid, and their recursively discovered shared libraries.
Host readelf inspects ELF files without executing target binaries. The kernel
does not embed this archive, avoiding a dependency cycle. Host cpio creates
root-owned archive entries without privileged filesystem operations. Genimage
then assembles the disk. `build.config` and `build-manifest.txt` record the
configuration, SHA-256 and measured output sizes after a successful build.
UUIDs are generated afresh, so rebuilds are not promised to be byte-identical.

The initramfs waits up to 30 seconds for GRUB's system PARTUUID, mounts
SquashFS read-only and overlays it with tmpfs. Upper and work directories
share `/run`; the lower and backing mounts move into the real root before
switch_root. Boot failures give diagnostics and an initramfs shell, never a
format operation. **Keep the USB connected throughout the session.** The
SquashFS remains on the USB; it is not copied into RAM.

The default entry uses DRM/KMS and GL. Recovery uses DRM/KMS and Pixman.
Intel i915, AMD amdgpu, QEMU virtio/Bochs/QXL, USB storage/UAS, common Ethernet
and USB Ethernet drivers are selected. i915/amdgpu and Realtek 8169 firmware
are deliberately included. Intel/AMD GPU drivers are modules so firmware is
available from the real root when udev loads them. The Dell Latitude 7280 with Intel HD 620 has been tested by the user;
AMD and QEMU coverage remains unverified. NVIDIA, very new Intel Xe hardware and Wi-Fi are outside the first configuration. Pixman does
not fix missing KMS support. USB input and common laptop input are included.

## Desktop

Weston desktop-shell starts as `tech` (UID/GID 1000) on tty1 through a
systemd service with PAM and logind; libseat uses logind. PAM establishes the
private `/run/user/1000` directory and dbus-run-session supplies the session
bus. There is no seat daemon or broad device chmod. A stopped/crashed Weston
restarts after five seconds, with a four-starts-per-minute limit. tty2 is an
autologin console for tech (Ctrl+Alt+F2); return using Ctrl+Alt+F1. The tech password is locked. The temporary SSH debug configuration enables
root password login as described below. Physical access grants this ordinary local session.

Panel launchers open Terminal, Nano, Midnight Commander, MiniBrowser, Unlock
Data, Lock Data and Shutdown, in that order. Browser UI is MiniBrowser's URL
entry/navigation, not a full Firefox replacement. The normal launcher opens
an offline welcome page. GTK uses Wayland; Xorg/XWayland are absent. Browser
sandboxing remains enabled. No package manager or target compiler is added.

Home, browser data, `/etc` and `/var` are volatile through the root overlay;
`/run` and `/tmp` are tmpfs, and journal storage is volatile. machine-id starts
empty and is generated per boot. Ethernet uses networkd DHCP, resolved's
stub resolver and timesyncd. Network availability does not gate the desktop.
The temporary debug build includes SSH (see below); Wi-Fi management and
automatic internal-disk mounting remain disabled.
GPT autodiscovery and hibernation resume generators are disabled.

## Provision a USB (destructive, manual)

Host tools: bash, coreutils, util-linux (lsblk/findmnt/flock/blkid/blockdev,
swapon), gdisk (`sgdisk`), parted (`partprobe`), udev (`udevadm`), cryptsetup,
and e2fsprogs. Check model, serial and partitions yourself before confirming.
Use an explicit whole-device path, never a partition. Example placeholders:

```sh
sudo amd64-extree/scripts/provision-usb.sh output-amd64/images/usb-live.img /dev/disk/by-id/YOUR_USB --data
# Omit --data for a boot-only USB.
```

The script displays the target and requires `ERASE /dev/<resolved-device>` on
`/dev/tty`. It rejects mounted devices, holders, active swap, the running
root/boot disks, physical non-USB/non-removable devices, partitions, disks
with non-512-byte sectors, and insufficient space. It writes the image,
repairs the backup GPT, randomizes disk/partition GUIDs, updates GRUB and,
optionally, creates partition 3 in remaining space. LUKS2 and ext4 are newly
created; cryptsetup prompts directly on the terminal. No shared LUKS header,
keyfile or passphrase is shipped. Failures stop; they do not cause retries
that reformat anything. Inspect partial media manually before reprovisioning.
The EFI manifest contains only UUIDs and is parsed as data at runtime.

Disposable loop workflow (these commands have NOT been run here):

```sh
truncate -s 12G /tmp/amd64-test-usb.img
loop=$(sudo losetup --find --show --partscan /tmp/amd64-test-usb.img)
sudo amd64-extree/scripts/provision-usb.sh output-amd64/images/usb-live.img "$loop" --data
sudo sgdisk -v "$loop"
sudo lsblk -f "$loop"
sudo losetup -d "$loop"
```

Do not reuse a loop device containing valuable data. Provision a second test
file to verify all disk, partition and LUKS UUIDs differ.
An optional header backup is `sudo cryptsetup luksHeaderBackup DATA_PARTITION
--header-backup-file /secure/offline/location/header.img`; store it securely
away from the USB. It contains keyslots and permits restoration of old keys.

## Unlock, lock and persistence

Select Unlock Data and enter the passphrase in its terminal. The helper
checks partition 3 belongs to the same disk as the boot system partition,
checks the EFI manifest's system/data PARTUUIDs and LUKS UUID, then opens only
`live-data` and mounts ext4 at `/data`. It serializes concurrent operations,
rejects foreign mappings/mounts, and handles repeated unlocks. Missing data
and incorrect passphrases leave the desktop usable. Documents belong in
`/data/tech/Documents`, created with ownership 1000:1000 during provisioning.
Nothing automatically persists the home directory or system overlay.

Select Lock Data to unmount and close the mapping. If busy, close files and
browser windows and leave `/data` in all terminals; retry. There is no force
or lazy unmount. Shutdown stops the desktop then invokes the same cleanup
before filesystem shutdown. Use the panel's normal systemd shutdown.

For explicit browser persistence, run `live-browser-persistent` from the
terminal after unlocking. It validates the mapped mount using the privileged
helper's read-only status operation before creating profile directories, and
keeps its current directory on that filesystem while the browser runs. GTK3
MiniBrowser's GLib XDG data/cache paths are redirected to `/data/tech/Browser`;
there is no assumed `--profile` CLI flag. The build's post-build script checks
these source contracts and the terminal launch option against downloaded
sources. Cookies/password-manager behavior is not promised or runtime-tested;
no credentials are deliberately persisted outside LUKS.

## QEMU and recovery

Install qemu-system-x86 and OVMF on the host, then:

```sh
amd64-extree/scripts/test-qemu.sh output-amd64/images/usb-live.img
# Or use a provisioned loop backing file after detaching its loop device:
amd64-extree/scripts/test-qemu.sh /tmp/amd64-test-usb.img
```

Override `OVMF_CODE` and `OVMF_VARS` if needed. The helper uses private NVRAM,
USB emulation, virtio graphics/networking, 4 GiB RAM, and a temporary QEMU
snapshot. It does not write the input image. Select both GRUB entries in
separate tests. Persistence across a guest reboot can be tested in one QEMU
process; snapshot changes disappear when QEMU exits. For cross-process tests,
use a disposable qcow2 overlay and remove the helper's `snapshot=on` in a
local test invocation, never attach a physical host disk.

On tty2, inspect `journalctl -b -u live-weston`, `loginctl`, `networkctl`,
`resolvectl`, `findmnt /data`, and `sudo /usr/bin/live-data status`. If restart
limiting was hit, reboot to retry. An initramfs failure shell can inspect
`cat /proc/cmdline`, `blkid` and `/sys/class/block`. Recovery never formats.

See `VALIDATION.md` for the remaining build/boot/provisioning acceptance matrix.

### Early boot: libpam.so.0 cannot be opened

The initramfs must use `/lib64 -> lib`, matching the amd64 loader's search
path. An earlier post-image script created separate directories, making
libraries in `/lib` unreachable. The corrected script now checks the complete
ELF dependency closure before creating the archive.

Regenerate the image using the existing build (from this repository's parent
of `buildroot` and `amd64-extree`):

```sh
make -C buildroot O="$PWD/buildroot/output" \
  BR2_EXTERNAL="$PWD/amd64-extree" BR2_JLEVEL=2
```

This reuses completed package builds and reruns image assembly. No clean,
WebKit rebuild or kernel rebuild is needed for this layout correction. Then
write the regenerated usb-live.img to disposable test media again. Re-running
the provisioning script erases existing encrypted data; back it up first if
needed. A successful archive check is not a claim that hardware boot passes.

## Temporary SSH debugging (root / root)

At the user's request, the current defconfig enables Dropbear on port 22 and
root password login with password `root` to diagnose the black display.
This intentionally supersedes the original no-SSH/locked-root appliance
policy for this debugging image. Use it only on a trusted LAN.

The active existing build configuration is `buildroot/.config`, with outputs
under `buildroot/output`. It has been updated without resetting other settings.
From the `buildroot` directory, rebuild manually:

```sh
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2
```

This builds Dropbear and regenerates the root filesystem and USB image; it
reuses completed package builds. Rewrite `output/images/usb-live.img` to the
test USB, boot it, and find its Ethernet address in the router's DHCP leases.
From another machine:

```sh
ssh root@USB_IP
# Password: root
systemctl --no-pager --full status live-weston.service systemd-logind.service
journalctl -b -u live-weston.service --no-pager
journalctl -b -k --no-pager
loginctl list-sessions
ls -l /dev/dri /run/user/1000
```

To save the entire boot journal directly onto your workstation:

```sh
ssh root@USB_IP 'journalctl -b --no-pager' > live-boot.log
```

SSH starts independently of Weston. The standard Buildroot Dropbear service
allows root/password authentication; with Linux-PAM selected it uses the
packaged sshd PAM policy. Host keys are generated at runtime and disappear on
reboot with the root overlay. Expect a changed-host-key warning on later boots;
verify the address belongs to this USB system before removing its old entry
with `ssh-keygen -R USB_IP`. No private host keys are included in the image.

After debugging, remove Dropbear and disable root password login in the
external defconfig, restore the corresponding assertions in scripts/check.sh,
and produce a fresh non-debug build. Setting a different password via `passwd`
in a running session only lasts until reboot.

### Dell Latitude 7280 touchpad

The Kaby Lake LPSS I2C controllers and Sunrise Point GPIO support are now
selected alongside HID-over-I2C. Earlier images omitted the bus drivers, so
only the USB touchscreen and keyboard appeared in libinput. From `buildroot`,
reconfigure/rebuild the kernel and then regenerate the image:

```sh
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2 linux-reconfigure
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2
```

After writing the new image and rebooting, check via SSH:

```sh
cat /proc/bus/input/devices
journalctl -b -k --no-pager | grep -Ei 'i2c|lpss|hid|touchpad|synaptics|elan|alps'
journalctl -b --no-pager | grep -Ei 'libinput|touchpad'
```

The touchpad is expected on an internal bus, so its absence from `lsusb` does
not establish a fault. The user confirmed working touchpad input after rebuilding.
The commands above are needed only when upgrading an older kernel configuration.

### Browser aborts opening libGL.so.1 or libOpenGL.so.0

The GTK/libepoxy desktop OpenGL path needs `libOpenGL.so.0`, even with
Wayland and EGL. The defconfig enables libglvnd 1.7.0, which builds this
library without GLX or X11 (see its
[src/meson.build](https://github.com/NVIDIA/libglvnd/blob/v1.7.0/src/meson.build)).
Mesa supplies the vendor EGL implementation; libglvnd supplies the public
EGL/GLES/OpenGL dispatch libraries. Do not symlink libGLESv2 to libGL.

For the existing in-tree build, enable `BR2_PACKAGE_LIBGLVND=y` with
`make menuconfig` if not already set (the working configuration was updated
with this fix), then run from `buildroot/`:

```sh
make BR2_EXTERNAL="$PWD/../amd64-extree" olddefconfig
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2 mesa3d-reconfigure
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2
```

This builds the new dependency and reconfigures Mesa before regenerating
`output/images/usb-live.img`. Existing WebKit binaries should remain usable.
Post-build checks require the dynamically loaded OpenGL library to exist.
After booting the updated image, run `live-browser` from the Weston terminal
as `tech`; capture terminal output if another error occurs. The user confirmed
that the browser works after this fix. Separate offline HTML, HTTPS and sandbox
acceptance tests have not been recorded.
