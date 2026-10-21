from pathlib import Path
import sys
import subprocess

root = Path(__file__).resolve().parent
for directory in ('build', 'results'):
    (root / directory).mkdir(parents=True, exist_ok=True)
sources = [root / 'Sources' / name for name in
           ('Localization.swift', 'ModelSearch.swift', 'Store.swift', 'IndexService.swift', 'Preferences.swift')]
subprocess.run(['xcrun', 'swiftc', '-O', '-parse-as-library', '-target',
                'arm64-apple-macosx14.0', '-module-cache-path', str(root / 'build/module-cache'),
                *map(str, sources), str(root / 'Tests/CoreTests.swift'),
                '-o', str(root / 'build/core-tests')], check=True)
subprocess.run([str(root / 'build/core-tests')], cwd=root.parent, check=True)
if '--layout' in sys.argv:
    ui_sources = sorted(p for p in (root / 'Sources').glob('*.swift') if p.name != 'main.swift')
    subprocess.run(['xcrun', 'swiftc', '-O', '-parse-as-library', '-target',
                    'arm64-apple-macosx14.0', '-module-cache-path', str(root / 'build/module-cache'),
                    *map(str, ui_sources), str(root / 'Tests/LayoutTests.swift'),
                    '-o', str(root / 'build/layout-tests')], check=True)
    subprocess.run([str(root / 'build/layout-tests')], cwd=root.parent, check=True)
