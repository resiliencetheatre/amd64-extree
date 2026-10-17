`weston/16.0.0/0001-clients-terminal-do-not-send-utf8-terminator.patch` fixes
the Weston terminal sending xkbcommon's terminating NUL byte after non-ASCII
key input. The patch is based on the `xkb_keysym_to_utf8()` API contract in
xkbcommon.h; no upstream commit is known. `linux/6.12.47/linux.hash` is copied
from board/pc/patches/linux/linux.hash in the pinned Buildroot revision; its
origin is kernel.org's signed checksum list. All downloads require hashes.
No upstream checkout files are modified.
