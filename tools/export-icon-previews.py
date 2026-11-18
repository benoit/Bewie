#!/usr/bin/env python3
"""Render all six native iOS appearances with the active Xcode Icon Composer."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
xcode = Path(subprocess.check_output(['xcode-select', '-p'], text=True).strip()).parent
renderer = xcode / 'Applications/Icon Composer.app/Contents/Executables/ictool'
for generation in [26, 27]:
    output = root / f'Design/Icons/iOS-{generation}'
    output.mkdir(parents=True, exist_ok=True)
    for rendition in ['Default', 'Dark', 'ClearLight', 'ClearDark', 'TintedLight', 'TintedDark']:
        subprocess.run([str(renderer), str(root / 'Bewie/AppIcon.icon'), '--export-image',
                        '--output-file', str(output / (rendition + '.png')), '--platform', 'iOS',
                        '--rendition', rendition, '--width', '1024', '--height', '1024',
                        '--scale', '1', '--design-generation', str(generation)],
                       check=True, capture_output=True)
        print(f'iOS {generation}: {rendition}')
