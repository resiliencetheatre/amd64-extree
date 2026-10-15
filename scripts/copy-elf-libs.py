#!/usr/bin/env python3
"""Copy target ELF dependencies using readelf, never executing target code."""
import pathlib
import re
import shutil
import subprocess
import sys

root, dest, binary = map(pathlib.Path, sys.argv[1:])


def resolve_target(name):
    """Resolve absolute as well as relative links inside the target root."""
    pending = list(pathlib.PurePosixPath(name).parts)
    resolved = []
    links = 0
    while pending:
        part = pending.pop(0)
        if part == '/':
            resolved = []
            continue
        if part in ('', '.'):
            continue
        if part == '..':
            if not resolved:
                raise SystemExit('Target link escapes root: ' + name)
            resolved.pop()
            continue
        path = root.joinpath(*resolved, part)
        if path.is_symlink():
            links += 1
            if links > 40:
                raise SystemExit('Target symlink loop: ' + name)
            pending = list(pathlib.PurePosixPath(path.readlink()).parts) + pending
        else:
            resolved.append(part)
    return root.joinpath(*resolved)


queue = [binary]
seen = set()
while queue:
    elf = queue.pop()
    info = subprocess.check_output(['readelf', '-l', '-d', str(elf)], text=True)
    names = re.findall(r'Shared library: \[(.*?)\]', info)
    names += re.findall(r'Requesting program interpreter: (.*?)\]', info)
    for name in names:
        if name in seen:
            continue
        seen.add(name)
        candidates = [name] if name.startswith('/') else [
            d + '/' + name for d in ('lib', 'lib64', 'usr/lib', 'usr/lib64')]
        source = next((p for n in candidates if (p := resolve_target(n)).is_file()), None)
        if source is None:
            raise SystemExit('Missing target ELF dependency: ' + name)
        target = dest / (name.lstrip('/') if name.startswith('/') else 'lib/' + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o755)
        queue.append(target)
