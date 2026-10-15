# Baseline 1 — working Dell desktop

Recorded 2026-10-15. Local source tag: `baseline-1`.

The user built and tested the USB image on a Dell Latitude 7280 with an
Intel Core i5-7300U and Intel HD Graphics 620. The user confirms Weston,
touchpad, terminal, Nano, Midnight Commander and MiniBrowser now work.
Boot logs confirm systemd, PAM/logind, i915/GL rendering at 1920x1080,
wired DHCP and root SSH authentication. This is the first working desktop
baseline, not completion of the full persistence/provisioning acceptance suite.

## Source and build identity

- Buildroot: `acbcc911b71f93bb7ea9400aa19713f3464c8e69`.
- Configuration: `configs/amd64_usb_live_defconfig`.
- Package versions: `PACKAGE_VERSIONS.txt` (Linux 6.12.47, Weston 16.0.0,
  WebKitGTK 2.52.4, Mesa 26.1.8, libglvnd 1.7.0).
- Existing build: `../buildroot/.config`, output `../buildroot/output`.
- Active configuration saved to a temporary minimal defconfig and compared
  equal to the tracked external defconfig during baseline preparation.
- Upstream Buildroot tracked files remain unmodified.

The current local image's SHA-256 was independently checked against its
build-manifest.txt:

```text
b68383656bc4e87d8cb8c278e75c4bb5f6f41893887103f02e3544842064d48d  usb-live.img
```

| Artifact | Bytes |
| --- | ---: |
| usb-live.img | 541294592 |
| rootfs.squashfs | 271790080 |
| bzImage | 7357440 |
| boot-initramfs.cpio.gz | 1776040 |

Sizes are from the current build manifest. The USB itself was not read back
for comparison. Images and build outputs are intentionally outside the source
repository. Fresh image UUIDs mean rebuilds need not have the same checksum.
Cleanup after this image was built removes a duplicate, idempotent Dropbear
enablement block and trailing whitespace. Source checks skip Git metadata.
These changes do not change intended runtime behavior.

## Baseline choices

Retain the libclc compiler/triple compatibility settings, corrected initramfs
lib64 layout, Dell LPSS/I2C/GPIO drivers, and libglvnd OpenGL runtime. Keep
WebKit sandbox configuration and Wayland-only desktop. No speculative GPU
workaround is included: the user confirmed the clock advances when showing
seconds. Live diagnostic clock/pageflip edits are not baseline configuration.

SSH root/root remains enabled at the user's request for development on a
trusted LAN. Removing debug access is a separate future change. Default home,
browser profile and system edits remain ephemeral by design.

## Checks and next work

Baseline preparation passed configuration regeneration and minimal-defconfig
round trip, required/forbidden selections, overlay layout and shell syntax
checks. No image build or physical-device write was performed by the agent.

Still to record explicitly:

- Offline HTML, HTTPS and browser sandbox runtime verification.
- QEMU/OVMF boot, Pixman recovery, AMD graphics and other hardware coverage.
- Reboot tests for ephemeral home/root, machine ID and offline startup.
- LUKS provisioning, unique identities, unlock/lock failure cases, persistent
  documents/browser profile and shutdown with data mounted.
- Disposable second-disk protection and provisioning rejection tests.
- All remaining service-unit and launcher acceptance checks in VALIDATION.md.

Continue the current manual build using the README's in-tree commands.
Future source work should be committed after this baseline; generated files,
USB media and downloads must remain outside Git.
