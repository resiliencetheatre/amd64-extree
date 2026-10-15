#!/usr/bin/env python3
"""Check amd64 initramfs ELF dependencies without running target binaries."""
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(sys.argv[1]).resolve()
# These are the pinned amd64 glibc's built-in search directories. No host
# ld.so.cache, LD_LIBRARY_PATH or host libraries may mask a missing dependency.
search = [root / 'lib64', root / 'usr/lib64']
queue = [root / 'bin/busybox', root / 'bin/blkid']
seen = set()
while queue:
    elf = queue.pop()
    resolved = elf.resolve()
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise SystemExit(f'Missing or escaping initramfs ELF: {elf}')
    if resolved in seen:
        continue
    seen.add(resolved)
    info = subprocess.check_output(
        ['readelf', '-l', '-d', str(elf)], text=True,
        env={**os.environ, 'LC_ALL': 'C'})
    for interpreter in re.findall(r'Requesting program interpreter: (.*?)\]', info):
        queue.append(root / interpreter.lstrip('/'))
    for name in re.findall(r'Shared library: \[(.*?)\]', info):
        library = next((d / name for d in search if (d / name).is_file()), None)
        if library is None:
            raise SystemExit(f'{elf.name}: {name} is not reachable through /lib64 or /usr/lib64')
        queue.append(library)
print(f'Initramfs ELF check passed: {len(seen)} files, all dependencies reachable')
