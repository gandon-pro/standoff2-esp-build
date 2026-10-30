"""Static checks for the embedded-ESP IPA; device behavior is out of scope."""
import argparse
import plistlib
import struct
import zipfile
from pathlib import Path


def initializer_count(data):
    offset, count, found = 32, struct.unpack_from('<I', data, 16)[0], 0
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, offset)
        if command == 0x19:
            for index in range(struct.unpack_from('<I', data, offset + 64)[0]):
                section = offset + 72 + 80 * index
                name = data[section:section + 16].split(b'\0')[0]
                if name == b'__mod_init_func':
                    found += struct.unpack_from('<Q', data, section + 40)[0] // 8
                elif name == b'__init_offsets':
                    found += struct.unpack_from('<Q', data, section + 40)[0] // 4
        offset += size
    return found


parser = argparse.ArgumentParser()
parser.add_argument('ipa', type=Path)
args = parser.parse_args()
with zipfile.ZipFile(args.ipa) as archive:
    names = archive.namelist()
    assert not any(name.endswith(('/S2ESP.dylib', '.i64', '.id0', '.id1', '.id2', '.nam', '.til')) for name in names)
    prefix = 'Payload/Standoff2.app/'
    executable = archive.read(prefix + 'Standoff2')
    info = plistlib.loads(archive.read(prefix + 'Info.plist'))
    assert executable[:4] == bytes.fromhex('cffaedfe')
    assert struct.unpack_from('<II', executable, 4)[0] == 0x100000C
    assert struct.unpack_from('<I', executable, 12)[0] == 2
    assert b'S2ESP-diagnostics.log' in executable
    assert b'runUIApplicationMainWithArgc:argv:' in executable
    assert b'S2ESP.dylib' not in executable
    assert info['UIFileSharingEnabled'] and info['LSSupportsOpeningDocumentsInPlace']
    assert prefix + 'Frameworks/UnityFramework.framework/UnityFramework' in names
    print('files', len(names), 'initializer_entries', initializer_count(executable),
          'static_launcher_bytes', len(executable), 'dylib_absent', True)
    assert initializer_count(executable) > 0
