"""Package a statically linked ESP launcher in the supplied app bundle."""
import argparse
import hashlib
import json
import plistlib
import stat
import struct
import zipfile
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('launcher', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    app, launcher_path, output = (p.resolve() for p in (args.app, args.launcher, args.output))
    if output.exists() or output.is_relative_to(app):
        raise ValueError('Output must be new and outside the app')
    info_path = app / 'Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    executable = app / info['CFBundleExecutable']
    original = executable.read_bytes()
    launcher = launcher_path.read_bytes()
    if launcher[:4] != bytes.fromhex('cffaedfe') or struct.unpack_from('<I', launcher, 4)[0] != 0x100000C or struct.unpack_from('<I', launcher, 12)[0] != 2:
        raise ValueError('Expected arm64 Mach-O executable')
    if b'S2ESP-diagnostics.log' not in launcher or b'overlay_installed' not in launcher:
        raise ValueError('Launcher does not contain the ESP diagnostics')
    info['UIFileSharingEnabled'] = True
    info['LSSupportsOpeningDocumentsInPlace'] = True
    shared_info = plistlib.dumps(info)
    prefix = 'Payload/' + app.name + '/'
    ida_suffixes = {'.i64', '.idb', '.id0', '.id1', '.id2', '.nam', '.til'}
    paths = sorted(p for p in app.rglob('*') if p.is_file() and p.suffix.lower() not in ida_suffixes)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=1, allowZip64=True) as archive:
        for index, path in enumerate(paths, 1):
            rel = path.relative_to(app)
            if '_CodeSignature' in rel.parts or rel.as_posix() == 'Frameworks/S2ESP.dylib':
                continue
            entry = prefix + rel.as_posix()
            if path == executable or path == info_path:
                zi = zipfile.ZipInfo(entry)
                zi.create_system = 3
                zi.external_attr = (stat.S_IFREG | (0o755 if path == executable else 0o644)) << 16
                zi.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(zi, launcher if path == executable else shared_info)
            else:
                archive.write(path, entry)
            if index % 400 == 0:
                print('Packaged', index, 'files', flush=True)
    with zipfile.ZipFile(output) as archive:
        assert archive.read(prefix + info['CFBundleExecutable']) == launcher
        assert plistlib.loads(archive.read(prefix + 'Info.plist'))['UIFileSharingEnabled']
        assert not any(name.endswith('/S2ESP.dylib') for name in archive.namelist())
        invalid = archive.testzip()
        if invalid:
            raise ValueError('Archive CRC failed: ' + invalid)
    report = {'ipa': str(output), 'bytes': output.stat().st_size,
              'launcher_sha256': sha(launcher), 'original_executable_sha256': sha(original),
              'esp_dylib_dependency': False, 'zip_crc_verified': True,
              'requires_resigning': True, 'device_tested': False,
              'integrity_bypass_verified': False, 'warden_bypass_verified': False}
    output.with_suffix('.verification.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
