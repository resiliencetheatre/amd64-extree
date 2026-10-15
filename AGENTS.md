# AMD64 Buildroot USB live desktop

## Goal

Implement a complete amd64 USB live system built by Buildroot. Boot directly
into a minimal Weston desktop with terminal tools, a text editor, and a web
browser. Use systemd and support a persistent LUKS2-encrypted data partition
on the same USB drive. Never install anything onto the computer's internal
disks.

The system is a fixed appliance image: no package manager, automatic updates,
installer, or distribution management layer. Shared libraries inside the
image are allowed and preferred; “static system” does not require static
linking.

## Start by inspecting the repository

- Read existing instructions and inspect the Buildroot version, defconfigs,
  BR2_EXTERNAL tree, board files, patches, and overlays.
- Create the dedicated amd64-extree external tree described below. If it
  already exists, extend it while preserving its conventions and user changes.
  Do not replace working configurations or external trees for other targets.
- Pin the Buildroot revision and package versions. Verify every Kconfig symbol
  and launch option against that revision; do not copy unverified symbols from
  this document or silently update Buildroot.
- Use pc_x86_64_efi_defconfig as a reference where available. Keep the new
  configuration independent of Raspberry Pi targets.
- Implement the project, not merely a proposal. Document blockers and which
  checks actually ran. Do not claim a successful build or boot without evidence.

## Required amd64-extree external tree

Create a Buildroot BR2_EXTERNAL tree named amd64-extree, normally as a sibling
of the Buildroot checkout. All project-specific modifications belong here.
Keep the upstream Buildroot checkout unmodified. If a required feature needs
a Buildroot infrastructure change rather than a package patch, retain that
change as a documented patch in amd64-extree and apply it reproducibly to a
disposable build checkout; never hide changes in the primary upstream checkout.

Use this initial layout, extending it when needed:

```text
amd64-extree/
  AGENTS.md
  README.md
  external.desc
  Config.in
  external.mk
  configs/
    amd64_usb_live_defconfig
  board/amd64-usb-live/
    linux.config
    genimage.cfg
    grub.cfg
    users.txt
    post-build.sh
    post-image.sh
    initramfs/
    rootfs-overlay/
  package/
  patches/
  scripts/
    build.sh
    provision-usb.sh
    test-qemu.sh
```

- external.desc must contain `name: AMD64_EXTREE` and a useful description.
  Buildroot then exposes BR2_EXTERNAL_AMD64_EXTREE_PATH.
- Config.in sources the Config.in files of custom packages as needed.
- external.mk includes custom package .mk files, conventionally through
  `include $(sort $(wildcard $(BR2_EXTERNAL_AMD64_EXTREE_PATH)/package/*/*.mk))`.
- Start with valid empty Config.in and external.mk files if there are no
  custom packages yet; do not create broken references or placeholder packages.
- Put defconfigs, kernel configuration, overlays, user tables, boot files,
  initramfs sources, units, helpers, provisioning tools, and documentation
  inside amd64-extree. Copy this instruction file into its AGENTS.md.
- Reference board files from the defconfig through
  `$(BR2_EXTERNAL_AMD64_EXTREE_PATH)`, rather than absolute developer paths.
- Keep package patches under a version-aware global patch directory, selected
  with BR2_GLOBAL_PATCH_DIR. Record patch origin and purpose. Prefer existing
  upstream packages; avoid overriding packages unless required by the pinned
  Buildroot version and supported by its external-tree mechanisms.
- build.sh resolves its own location, accepts or documents the Buildroot
  checkout path, passes an absolute BR2_EXTERNAL path, and builds unprivileged
  into a separate output directory. Never bake the developer's home path into
  configuration. Do not run Buildroot itself with sudo.
- Keep generated output, downloads, caches, disk images, and test media outside
  the tracked external-tree sources, or explicitly ignore them.
- Record the required Buildroot revision in the external tree. Do not vendor
  the full Buildroot source into it.

Document and validate this command pattern, adapting only paths to the actual
repository layout:

```bash
# Run from the parent containing buildroot/ and amd64-extree/.
make -C buildroot O="$PWD/output-amd64" \
    BR2_EXTERNAL="$PWD/amd64-extree" amd64_usb_live_defconfig
make -C buildroot O="$PWD/output-amd64" \
    BR2_EXTERNAL="$PWD/amd64-extree"
make -C buildroot O="$PWD/output-amd64" \
    BR2_EXTERNAL="$PWD/amd64-extree" savedefconfig \
    BR2_DEFCONFIG="$PWD/amd64-extree/configs/amd64_usb_live_defconfig"
```

The external tree must work from a fresh checkout with only the documented
Buildroot revision and host prerequisites. Check that the named defconfig is
discoverable when BR2_EXTERNAL is set, and that savedefconfig writes it back
to amd64-extree rather than upstream configs/.

## Architecture and boot

- Generic x86-64 baseline compatible with ordinary Intel and AMD laptops.
  Do not compile for the build host's native CPU.
- Buildroot-built glibc toolchain with C++, threads, and shared libraries.
- UEFI boot using GRUB at EFI/BOOT/BOOTX64.EFI. Initial target is unsigned
  boot with Secure Boot disabled. Legacy BIOS is outside the first version.
- Produce $O/images/usb-live.img as a raw GPT disk image using genimage, where
  O is the chosen Buildroot output directory (default output-amd64).
- Use an EFI FAT32 partition for GRUB, kernel, and a small initramfs, followed
  by a partition containing a SquashFS root filesystem.
- GRUB passes the system partition's PARTUUID. The initramfs discovers and
  mounts that partition read-only, constructs a tmpfs-backed OverlayFS root,
  and hands control to the real root's systemd.
- Ensure OverlayFS upper and work directories share a filesystem. Preserve
  the lower mount and overlay backing mounts across switch_root.
- Bound USB discovery waits and provide useful diagnostics if discovery or
  mounting fails. Never fall back to formatting a disk.
- Avoid a kernel/initramfs dependency cycle. Define an explicit build sequence
  for the small boot initramfs and large desktop root filesystem.
- The USB must remain connected while running. Do not imply that the entire
  SquashFS image is copied into RAM.
- Changes to system files and the default home directory disappear on reboot.
- Include a normal GPU-rendered boot entry and a Pixman software-rendered
  recovery entry using options supported by the packaged Weston version.

## Desktop and applications

- Weston on DRM/KMS with desktop-shell.so; Weston performs window management.
- Wayland-native clients. No Xorg or XWayland in the initial configuration.
- Mesa EGL/GLES, libdrm, libinput, libxkbcommon, and suitable fonts.
- Weston terminal, Nano, Midnight Commander, and WebKitGTK MiniBrowser.
- Verify MiniBrowser support in the pinned Buildroot tree. If missing,
  backport a small appropriate packaging change into BR2_EXTERNAL or report
  the exact limitation; do not silently substitute a kiosk-only browser.
- Configure the supported GTK stack for Wayland. Keep WebKit's sandbox
  enabled and provide its kernel/runtime dependencies.
- Browser UI must support URL entry and basic navigation. Treat it as a basic
  browser, not a promise of Firefox feature parity.
- Supply panel launchers for Terminal, Editor, Files, Browser, Unlock Data,
  Lock Data, and Shutdown. Use installed icons and valid executable paths.
- Launch Editor and Files through terminal wrapper scripts. Nano edits files
  in the RAM-backed home until the user explicitly saves to /data.
- Include BusyBox, Bash, less, findutils, grep, curl, iproute2, ethtool,
  pciutils, usbutils, and CA certificates as supported by the selected tree.
- No compiler, development headers, or build toolchain on the target.

## Systemd and user session

- Use systemd as PID 1 and its integrated udev implementation; do not add
  standalone eudev or BusyBox init.
- Use systemd-logind with a Weston-compatible seat backend. Inspect whether
  the packaged Weston uses libseat/logind or a direct logind launcher.
- Create ordinary user tech with a fixed UID/GID, used consistently for data
  ownership. Do not run the browser or desktop as root.
- Start Weston automatically on a dedicated VT through a real login session
  with the required PAM/logind integration. Provide a separate console VT.
- Ensure XDG_RUNTIME_DIR is owned by tech with mode 0700, and establish a
  session D-Bus when applications require it. No world-writable runtime path.
- Device access must follow the active seat/session, not broad chmod rules.
- Ensure /etc, /var, /run, /tmp, and home have appropriate writable storage.
  Journal storage is volatile. Handle machine-id correctly for a generic
  read-only image, including per-boot generation where appropriate.
- Restart a crashed compositor without uncontrolled rapid restart loops.
- Include a normal systemd shutdown path that unmounts encrypted data before
  device mappings are closed.

## Networking

- systemd-networkd provides Ethernet DHCP; systemd-resolved provides DNS.
- Configure /etc/resolv.conf for the chosen resolved mode and writable layout.
- Network unavailability must not delay or prevent the desktop starting.
- Enable time synchronisation when online for usable HTTPS; handle offline
  boot without making network access mandatory.
- Wi-Fi through iwd is optional; add it only when target hardware is known or
  explicitly requested. Do not enable an SSH server by default.

## LUKS2 persistent data

- Include cryptsetup, its LUKS2/Argon2 dependencies, ext4 tools, and appropriate
  systemd cryptsetup integration where needed.
- Kernel needs device mapper, dm-crypt, AES/XTS and relevant crypto support.
- The data partition contains LUKS2 with ext4 inside. Mount at /data through
  /dev/mapper/live-data. Create /data/tech owned by the fixed tech UID/GID.
- Desktop boot never prompts for this optional partition. Do not create an
  automatic crypttab/fstab dependency that blocks boot or forces recovery mode.
- Unlock Data opens a terminal and invokes a narrowly scoped privileged
  helper. Discover only the provisioned partition belonging to the boot USB,
  validate its LUKS UUID, prompt on /dev/tty, open it, then mount it.
- Keep data identity outside the immutable SquashFS, for example a provisioning
  manifest on the EFI partition. Validate manifest fields as data, never source
  them as shell code. Do not scan and unlock unrelated LUKS volumes.
- Never pass a passphrase in argv, logs, shell tracing, environment variables,
  image contents, or persistent temporary files.
- Missing data, a wrong passphrase, and repeated unlock attempts must be
  recoverable without affecting the desktop. Handle partial failures and
  concurrent helper invocations safely; make repeated successful unlocks
  idempotent.
- Lock Data unmounts /data and closes live-data. If busy, explain and refuse;
  do not use forced or lazy unmounting. Normal shutdown must also clean up.
- Restrict helper privilege to these operations and this data target. Avoid
  arbitrary command execution, caller-controlled mount options, and broad
  passwordless sudo. Validate mountpoints and reject unsafe symlinks.
- Keep the default home and browser profile ephemeral. Provide an explicit
  persistent-browser launcher only after confirming /data is mounted from the
  correct decrypted mapping. Never let it silently write a profile to an
  unmounted /data directory. Verify supported browser profile options.
- Persistent documents live in /data/tech/Documents. Do not automatically
  persist the whole root filesystem or store browser passwords outside LUKS.

## USB provisioning and disk protection

- Buildroot builds all target software. A separate host-side provisioning
  script writes the image and creates an optional data partition in remaining
  space, generates unique identifiers, formats LUKS2, and creates ext4.
- Never embed a common encrypted volume, passphrase, keyfile, or LUKS header
  in the distributable image.
- Require an explicit whole-device target. Display model, size, serial where
  available, and existing partitions; require destructive-write confirmation.
- Reject the running root/boot disk, mounted target partitions, active device
  mapper/swap holders, insufficient capacity, and a partition passed as a disk.
- Never guess a target from /dev/sda or /dev/sdb. Make partition-path handling
  work with sdX, NVMe, and loop devices.
- Repair the backup GPT position after expanding onto a larger USB before
  creating the data partition. Preserve the boot and system partitions.
- Support testing against disposable loop devices. Do not flash or format a
  physical device during development without explicit authorization.
- Document host dependencies, passphrase entry, and an optional LUKS header
  backup procedure. Provisioning errors must not trigger automatic reformatting.
- Runtime must not auto-mount internal drives, activate their swap, unlock
  their encrypted volumes, or write boot entries into firmware NVRAM.

## Kernel and firmware

- Built-in or initramfs-provided USB host, storage/UAS, SCSI disk, GPT,
  SquashFS, OverlayFS, and tmpfs support sufficient to mount the live root.
- EFI/simpledrm early display support; Intel and AMD DRM drivers with firmware
  appropriate to the actual intended hardware.
- Keyboard, mouse, USB HID, laptop touchpad, evdev, VT, and networking drivers.
- Include QEMU virtio storage, network, and graphics support for testing.
- Include kernel features required by systemd, udev, Mesa, and WebKit sandboxing.
- Select firmware deliberately; record hardware coverage and known gaps.
  Software rendering does not guarantee display support on every GPU.

## Deliverables

Keep all project-specific implementation in amd64-extree:

- A functional external.desc, Config.in, and external.mk with the
  BR2_EXTERNAL_AMD64_EXTREE_PATH integration described above.
- A dedicated amd64 USB desktop defconfig.
- Board kernel config/fragments, genimage config, and post-build/post-image
  scripts with an explicit initramfs build workflow.
- Rootfs overlay containing systemd units, session setup, weston.ini,
  launchers, and data helpers.
- Host provisioning script with a disposable-image/loop-device test path.
- README with exact build, USB provisioning, boot, unlock/lock, persistence,
  troubleshooting, and recovery commands, plus required host tools.
- Build/version manifest and measured output sizes once available.

Use actual repository paths in documentation. Commit source configuration,
not generated output trees, downloaded sources, or disk images. Preserve
unrelated user edits.

## Validation and acceptance

- Run configuration regeneration and inspect the resulting configuration for
  silently dropped options or unmet dependencies. Save a minimal defconfig.
- Run appropriate shell syntax checks and Buildroot package checks for changed
  custom packages. Validate systemd units using a compatible systemd version.
- Build the complete image when host resources permit. State any resource or
  dependency blocker precisely rather than claiming success.
- Boot with QEMU/OVMF and confirm real systemd startup, Weston desktop,
  terminal, editor, file manager, and browser. Verify local HTML offline and
  HTTPS when a network is available.
- Test both renderer boot entries. Record what was tested virtually versus
  on physical hardware.
- Verify root changes disappear after reboot; encrypted documents survive
  reboot and are unavailable before unlocking.
- Test absent data partition, wrong passphrase, repeat unlock, busy lock,
  successful lock, and shutdown while data is mounted.
- Attach a disposable extra disk to QEMU; verify its contents and partition
  table remain unchanged, with no automatic mounts or swap activation.
- Provision disposable test media and verify unique LUKS identifiers,
  correct GPT sizing, filesystem ownership, and boot/data identity resolution.
- The task is complete when the reproducible image and provisioning workflow
  meet these requirements. Clearly list any acceptance checks not performed.
