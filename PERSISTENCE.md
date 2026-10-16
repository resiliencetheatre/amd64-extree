# First-boot encrypted persistence

Implemented in source; physical/VM provisioning and shutdown tests are still
required. No disks have been formatted or flashed by the agent.

## Boot flow

The default GRUB entry now starts a local tty1 setup/unlock prompt before
Weston, console logins, iwd and ALSA state services. Ethernet/SSH may start
independently for debugging; no network is needed to unlock the USB.

On a newly written image, choose **c** to create storage. The helper accepts
only the actual USB disk backing the mounted read-only SquashFS partition.
It requires the expected two-partition GPT layout and at least 1 GiB of unused
tail space. It displays the model, serial, size and partitions, then requires
`CREATE /dev/<actual-boot-disk>` typed exactly. Nothing selects /dev/sda by
convention. Partition device names are discovered through lsblk, not assembled
by appending digits.

The helper saves a GPT backup on the EFI partition, relocates the backup GPT
to the end of the USB, adds partition 3, and verifies partitions 1 and 2 retain
their metadata. It uses partx to publish only the new partition when a full
kernel partition-table reread is unavailable because SquashFS is mounted.
It rejects existing signatures in the new extent. cryptsetup asks for a NEW
LUKS2 passphrase twice, then asks to unlock it for ext4 creation. Passphrases
are never read into shell variables, argv, logs or files. The open mapping is
handed to activation after the manifest has been written durably.

On later boots, the existing EFI manifest is checked and the local prompt
asks for the existing passphrase. A wrong passphrase leads to a menu with
**u** to retry, **e** to explicitly boot temporarily, and **p** to power off.
A host-provisioned `--data` USB uses the same manifest and is also supported.

GRUB includes **ephemeral recovery** entries with both GL and Pixman. These
skip all data opening and provisioning. They are useful for inspecting an
interrupted setup. Choosing **e** in the prompt likewise requires successful
cleanup first. There is no silent fallback to a different home after a failed
unlock. No startup timeout forces a choice on an unattended machine.

## Persistent and temporary paths

| Encrypted backing directory | Runtime path | Owner |
| --- | --- | --- |
| /data/tech/home | /home/tech | tech, UID/GID 1000 |
| /data/system/iwd | /var/lib/iwd | root, mode 0700 |
| /data/system/alsa | /var/lib/alsa | root, mode 0700 |
| /data/tech/Documents | ~/Documents on a new home | tech |

The directories are bind-mounted before their consumers start. Initial home
contents are copied once from the image's RAM-backed home through a staging
directory; existing persistent homes are never overwritten or recursively
chowned. Symlinked parents/mountpoints are rejected. Existing documents from
host provisioning remain in /data/tech/Documents. If an existing home already
has Documents, it is preserved rather than replaced with a link.

Normal browser profiles now persist with the home in persistent mode. They
remain volatile in ephemeral mode. The older `live-browser-persistent` helper
still provides a separate explicit profile for an ephemeral session after
manual data unlock. These two profiles are not automatically merged.

/etc, the rest of /var, machine-id, journals, /run and /tmp remain temporary.
OS and networkd defaults belong in the source overlay. Wi-Fi passwords live
only in encrypted /var/lib/iwd storage; do not put them on the EFI partition.
This is selective persistence, not a persistent writable root or package manager.
Per-device ALSA state can differ when moving the USB between laptops.

## Locking and shutdown

Lock Data refuses while persistent home/settings bindings are active. Use
normal shutdown to close this session. systemd stops dependent services first;
the persistence stop helper terminates any remaining tech login sessions,
waits for their processes, unmounts the three bindings, then the existing data
cleanup service unmounts /data and closes live-data. No forced/lazy unmount is
used. If a mount is busy or has an unexpected identity, cleanup fails visibly
and does not force the mapping closed. The shutdown sequence still needs
verification on the target systemd version and actual media.

## Interrupted setup / unexpected media

Creation refuses extra partitions, active swap, holders, unexpected mounts,
non-USB disks, a read-only disk, non-512-byte sectors, existing manifests or
incomplete-setup markers. It never reformats an existing partition to repair an
unlock failure. Original GUIDs are retained; the new partition and LUKS volume
get their own identifiers. Internal disks are not scanned for candidate data.

`live-data.pending` is written on EFI before GPT changes. If creation fails or
power is lost, that marker blocks automatic activation and recreation. Boot
ephemeral recovery and inspect the table, filesystem and LUKS header manually.
The stored `live-gpt-before-data.bin` is diagnostic/recovery material; never
restore it blindly after successful data creation. Do not delete the pending
marker to retry formatting unless the partial state has been understood.
If a partition already exists without a valid manifest, no automatic adoption
or formatting is attempted. A finalization failure may leave a valid volume
requiring manual manifest recovery.

A separately stored LUKS header backup is recommended after successful setup:
`cryptsetup luksHeaderBackup DATA_PARTITION --header-backup-file SECURE_PATH`.
Choose SECURE_PATH on separate protected storage, not the same USB.

## Manual build and acceptance

From the existing in-tree buildroot directory:

```sh
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2 linux-reconfigure
make BR2_EXTERNAL="$PWD/../amd64-extree" BR2_JLEVEL=2
```

The active configuration includes sgdisk, partx, wipefs and procps-ng; prior
ALSA/Wi-Fi kernel changes are included. No build was run by the agent.
Do not overwrite a provisioned USB with a new raw image expecting it to preserve
the partition table/data identity; an in-place OS update workflow is not yet
implemented. Back up data before reflashing.

Test first on a disposable USB (or a disposable QEMU USB-storage disk, not
virtio for first-boot provisioning). Keep another disposable disk attached to
verify it remains untouched. Required tests:

1. Fresh two-partition image: cancel creation and choose ephemeral mode; verify
   no new partition. Then reboot, confirm creation and record GUIDs/headers.
2. Verify EFI/system partition metadata and system partition hash are unchanged;
   backup GPT is at device end; partition 3 is LUKS2 with ext4 inside.
3. Confirm Weston/tty2/iwd start only after unlock; inspect `findmnt /home/tech`,
   `findmnt /var/lib/iwd`, `findmnt /var/lib/alsa` and ownership under /data.
4. Save a home document, connect Wi-Fi, set mixer levels, shut down and reboot.
   Verify passphrase prompt, saved files/profiles/state, and `/etc` volatility.
5. Wrong passphrase, absent data, extra partition, pending marker, and insufficient
   space must never format storage. Verify explicit ephemeral mode still works.
6. Test reboot/poweroff with apps open, a deliberately busy /data, and repeated
   unlock. Check journal for unmount/cryptsetup failures. Lock Data must refuse
   while persistent home is active.
7. Hash the unrelated disk before/after, and confirm no mount/swap activation.

Read-only fixture tests: `python3 amd64-extree/tests/test_persistence.py`.
They test guard decisions and path safety, not actual GPT writes, encryption,
service ordering, power-loss durability or hardware behavior.
