# Validation record

## Current status: baseline 1 (2026-10-15)

The user manually built and booted the image on a Dell Latitude 7280, and
confirmed working Weston, touchpad, terminal, Nano, Midnight Commander and
MiniBrowser after the libglvnd fix. Supplied logs also show systemd/PAM/logind,
i915 hardware rendering, Ethernet DHCP and successful root SSH authentication.
See [BASELINE.md](BASELINE.md) for the image identity and remaining tests.

The dated sections below are historical investigation records. Their statements
about missing build/boot evidence describe the state at that time, not the
current baseline. QEMU, encrypted persistence and disk-protection acceptance
remain unverified; a working desktop does not complete those checks.

## Initial implementation checks (2026-10-14)

The user explicitly requested implementation without building the image.
No target package compilation, kernel compilation, image generation, VM boot,
loop formatting or physical-device operation was performed.

Completed:

- Read root AGENTS.md and copied it into this external tree.
- Inspected the clean upstream revision, PC EFI reference, package Kconfig and
  makefiles. Native MiniBrowser support means no backport is required.
- Discovered `amd64_usb_live_defconfig` through `make list-defconfigs`.
- Generated configuration, checked no requested symbols were silently dropped,
  inspected glibc/shared/C++/systemd/logind/Mesa/Wayland/MiniBrowser/sandbox and
  forbidden Xorg/SSH/seatd selections. Corrected obsolete curl and hidden C++
  symbols before saving the minimal defconfig to this external tree.
- `olddefconfig` and `savedefconfig` round trip; source shell/Python syntax and
  upstream `check-merged -t overlay -u -b` pass via `scripts/check.sh`.
- Upstream `check-package --br2-external` applied to Config.in, external.mk and
  the defconfig. Kernel hash copied from the pinned PC reference to enable
  mandatory download hash checking. There are no custom packages to lint.
- `make show-info` resolved selected package versions without building them;
  recorded in PACKAGE_VERSIONS.txt.
- Host systemd 257.13 verified copies of both service units with Exec paths
  replaced by `/usr/bin/true`. Direct validation of originals reports missing
  target executables on the host. This is syntax/ordering validation only;
  matching target systemd 258.7 validation is still required after the build.
- Upstream Weston 16 frontend source confirms DRM backend and gl/pixman renderer
  selection: https://raw.githubusercontent.com/wayland-mirror/weston/16.0.0/frontend/main.c

Limitations and required follow-up:

- Network DNS from the shell was unavailable. Exact Weston terminal and
  MiniBrowser source retrieval also failed via the browsing tool. The
  post-build script explicitly verifies `--shell` and MiniBrowser XDG data/cache
  source contracts against the downloaded pinned sources; these checks have
  not run yet. A failed assertion requires resolving that contract, not
  bypassing the assertion. No unverified `--profile` option is used.
- Kernel fragment has not been regenerated against downloaded Linux sources.
  Kernel selections and required built-in boot drivers must be inspected after
  `linux-menuconfig`/the manual build. No successful kernel configuration or
  image is claimed. BusyBox fragment also awaits package configuration.
- No ShellCheck binary was available; sh/bash syntax checks were used.
- No output sizes exist yet. Post-image will record measured sizes and hashes.
- No physical hardware has been tested; intended Intel/AMD/QEMU coverage is a
  configuration choice, not a hardware certification.

Acceptance checklist for the manual build/test phase:

1. Build usb-live.img; inspect post-build source checks, Linux and BusyBox final
   configurations, image GPT/FAT/SquashFS, package manifest and image sizes.
2. Verify original units using the built host-systemd verifier against the
   complete target filesystem, then boot QEMU/OVMF with both GL and Pixman.
3. Confirm real systemd, PAM/logind session, private runtime directory, session
   bus, Weston, all seven panel launchers, local HTML and online HTTPS.
4. Modify /etc and home, reboot, verify changes disappear. Confirm machine-id
   is per-boot, logs remain volatile and offline boot reaches the desktop.
5. Provision two disposable loop files, verify GPT backup placement, distinct
   disk/partition/LUKS UUIDs, ext4 ownership and boot/data manifest resolution.
6. Test missing data, wrong password, repeated/concurrent unlock, mount failure,
   foreign mapping/mount rejection, busy lock, successful lock and shutdown
   while mounted. Check documents survive guest reboot but are inaccessible
   before unlocking. Check explicit browser persistence and busy-lock behavior.
7. Attach a disposable second disk (including filesystem and swap signatures)
   to QEMU; hash its complete contents before and after tests and verify no
   mounts, swap activation, encrypted-volume discovery or partition changes.
8. Test provisioning rejection paths using disposable fixtures: partition
   target, too-small device, mounted child, holder, swap and protected root.
   Do not test destructive operations on physical media without authorization.

## Follow-up: host-libclc 23.1.3 configuration failure

The user's manual build reached host-libclc and failed because CMake selected
GCC as the OpenCL compiler. `support/libclc.mk` now explicitly selects the
already-built host Clang for CLC and supplies LLVM 23's target-triple option.
Standalone CMake configuration/generation and its CLC compiler probe passed
against the user's extracted sources; make printvars confirmed integration.
No package or image build was resumed. See support/README.md for retry commands
and the remaining downstream-build validation boundary.

## Follow-up: physical boot stops loading libpam.so.0 (2026-10-15)

The reported photograph shows `/bin/sh` failing before `/init` can execute.
Inspection of the existing boot-initramfs.cpio.gz confirmed that libpam.so.0
was included under /lib. The pinned glibc build's elf/trusted-dirs.h lists
/lib64 and /usr/lib64, while the archive incorrectly used a separate /lib64
containing only the ELF interpreter. The real target correctly links lib64
back to lib. This was an initramfs assembly defect, not missing PAM packaging.

Post-image now creates the relative lib64 -> lib link before copying the ELF
closure. New scripts/check-initramfs.py checks the interpreter and recursive
DT_NEEDED dependencies against the actual amd64 loader search paths, without
running target code or consulting host libraries. It runs before archiving.

Validation: extracted the existing archive into output-amd64-check and confirmed
the checker rejects it; copied the current target BusyBox/blkid and dependency
closure into a fresh directory with the corrected link and the checker passed.
Post-image shell syntax passed. No image was regenerated or physical disk
written, and corrected physical/QEMU boot remains to be tested. The photograph
ending at 'Run /init as init process' alone does not identify a separate cause.

## Temporary remote debugging (2026-10-15)

The user reports systemd startup followed by an inaccessible black display and
explicitly requests SSH root/root. Enabled root password login and Dropbear
(server only, reverse DNS disabled) in the external defconfig and existing
buildroot/.config, preserving unrelated configuration. Added explicit service
enablement in post-build; inspected the pinned Dropbear service and PAM policy.
The user's instruction supersedes the original no-SSH requirement for this
image. Configuration was regenerated; no package/image build or remote login
was performed. The black-screen cause is still unknown pending boot logs.

## Dell Latitude 7280 touchpad (2026-10-15)

User boot logs confirm successful i915 firmware loading, Mesa Intel HD 620 GL
rendering, logind seat acquisition and eDP-1 output at 1920x1080. libinput sees
the keyboard and USB touchscreen, but no touchpad. The generated kernel has
I2C_HID_ACPI=y while Intel LPSS, DesignWare I2C, pinctrl and GPIOLIB are disabled.
Linux 6.12.47 drivers/mfd/intel-lpss-pci.c explicitly matches the 8086:9d60,
9d61 and 9d62 controllers present in the supplied PCI enumeration.

Enabled MFD_INTEL_LPSS_PCI/ACPI, I2C_DESIGNWARE_CORE/PLATFORM, PINCTRL,
GPIOLIB and PINCTRL_SUNRISEPOINT in the external kernel config. Ran kernel
olddefconfig against a separate copy of the existing kernel configuration at
output-amd64-check/linux-touchpad.config. All requested options and the
selected COMMON_CLK, PINCTRL_INTEL and I2C_HID_CORE dependencies resolve to y.
Only host Kconfig utilities were compiled; no kernel or image build was run.
The missing controller chain is a likely cause, not yet a hardware-confirmed
fix or identification of the touchpad vendor/model.

## Browser OpenGL runtime (2026-10-15)

User confirms the rebuilt image boots Weston, the touchpad works, and terminal,
editor and Midnight Commander launch. Browser aborts with libepoxy's missing
libGL.so.1/libOpenGL.so.0 error. Enabled libglvnd in the external defconfig and
active buildroot/.config. Inspected pinned Buildroot libglvnd/Mesa packaging
and upstream libglvnd v1.7.0 src/meson.build: OpenGL is built unconditionally,
whereas GLX/legacy GL are conditional. EGL/GLES dispatch resolve enabled;
Xorg/XWayland remain disabled. Added a post-build libOpenGL presence check.

Configuration regeneration, minimal defconfig round trip, required/forbidden
options, overlay and shell syntax checks passed via scripts/check.sh. No
package/image build or browser runtime test was performed. The clock advances
with the user's live seconds display setting; logs supplied no confirmed GPU
hang, so no speculative renderer workaround was committed.
