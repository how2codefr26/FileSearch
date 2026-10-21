"""Export a source-only allowlist; never copy local state or compiled products."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parent
NAME = 'FileSearch-v0.11-source'
files = {str(p.relative_to(ROOT.parent)): p.read_bytes()
         for p in sorted((ROOT / 'Sources').glob('*.swift'))}
for relative in ('build.py', 'build_icons.py', 'Assets/AppIcon.png', 'test.py', 'package.py', 'package_source.py',
                 'SOURCE_README.md', 'README.en.md', 'Tests/CoreTests.swift', 'Tests/LayoutTests.swift'):
    files['app/' + relative] = (ROOT / relative).read_bytes()
files['README.md'] = (ROOT / 'SOURCE_README.md').read_bytes()
files['README-English.md'] = (ROOT / 'README.en.md').read_bytes()
files['.gitignore'] = b'.DS_Store\napp/build/\napp/dist/\napp/results/\napp/testdata/\napp/release/\n'
files['SHA256SUMS'] = ''.join(
    hashlib.sha256(data).hexdigest() + '  ' + path + '\n'
    for path, data in sorted(files.items())).encode()
release = ROOT / 'release'
release.mkdir(exist_ok=True)
archive = release / (NAME + '.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
    for path, data in sorted(files.items()):
        info = zipfile.ZipInfo(NAME + '/' + path)
        info.create_system = 3
        info.external_attr = 0o100644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        output.writestr(info, data)
(release / (archive.name + '.sha256')).write_text(
    hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')
print(archive)
