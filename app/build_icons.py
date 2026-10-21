"""Convert the checked-in PNG master into a standard macOS multi-size ICNS."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
source = root / 'Assets/AppIcon.png'
iconset = root / 'build/AppIcon.iconset'
iconset.mkdir(parents=True, exist_ok=True)
for points in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        pixels = points * scale
        name = f'icon_{points}x{points}' + ('@2x' if scale == 2 else '') + '.png'
        subprocess.run(['/usr/bin/sips', '-z', str(pixels), str(pixels), str(source),
                        '--out', str(iconset / name)], check=True, stdout=subprocess.DEVNULL)
destination = root / 'build/AppIcon.icns'
subprocess.run(['/usr/bin/iconutil', '-c', 'icns', str(iconset), '-o', str(destination)], check=True)
print(destination)
