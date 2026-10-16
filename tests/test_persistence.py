#!/usr/bin/env python3
"""Read-only tests: shell guard fixtures and temporary-directory path checks.
No block device is opened or modified. Destructive helpers are never invoked.
"""
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'board/amd64-usb-live/rootfs-overlay/usr/libexec/live-persistence').read_text()
FUNCTIONS = SOURCE[SOURCE.index('safe_dir() {'):SOURCE.index('case $1 in\n')]
MOCKS = r'''
rootdev=/dev/test2; efi=/dev/test1; disk=/dev/test
lsblk() {
 case "$*" in
  '-nrpo NAME,TYPE /dev/test') printf '/dev/test disk\n/dev/test1 part\n/dev/test2 part\n'; [[ ${EXTRA:-0} == 0 ]] || echo '/dev/test3 part';;
  '-nrpo NAME /dev/test') printf '/dev/test\n/dev/test1\n/dev/test2\n';;
  '-dnro MAJ:MIN /dev/test') echo 8:0;;
  '-dnro MAJ:MIN /dev/test1') echo 8:1;;
  '-dnro MAJ:MIN /dev/test2') echo 8:2;;
  *) exit 99;;
 esac
 return 0
}
ls() { [[ ${HOLDER:-0} == 0 ]] || echo holder; return 0; }
findmnt() {
 echo '8:2 /run/live/lower'
 [[ ${MOUNT:-0} == 0 ]] || echo '8:1 /unexpected'
 return 0
}
wc() { echo "${SWAP_LINES:-1}"; }
sgdisk() { echo "Last sector: ${END:-1000000}"; }
blockdev() { echo "${SECTORS:-10000000}"; }
'''

def run(body):
    return subprocess.run(['bash', '-c', 'set -euo pipefail\nfail() { echo "$*" >&2; exit 1; }\n' + FUNCTIONS + '\n' + body], text=True, capture_output=True)

class Guards(unittest.TestCase):
    def test_creation_geometry(self):
        result = run(MOCKS + '\ncreation_checks; echo "$start"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(int(result.stdout), 1001472)

    def test_rejections(self):
        for variable, message in [('EXTRA=1', 'extra partitions'), ('HOLDER=1', 'holder'),
                                  ('MOUNT=1', 'EFI mounts'), ('SWAP_LINES=2', 'swap'),
                                  ('SECTORS=2000000', 'unused tail'), ('END=oops', 'geometry')]:
            with self.subTest(variable=variable):
                result = run(MOCKS + '\n' + variable + '\ncreation_checks')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)

    def test_directory_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'real').mkdir()
            (root / 'link').symlink_to(root / 'real')
            result = run(f'safe_dir "{root}/link/child"')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / 'real/child').exists())
            self.assertEqual(run(f'safe_dir "{root}/plain/child"').returncode, 0)

if __name__ == '__main__':
    unittest.main()
