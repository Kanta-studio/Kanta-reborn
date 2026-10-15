#!/usr/bin/env python3
"""Verify the distributed still pack using only the Python standard library."""
import hashlib
import json
from pathlib import Path
import struct
import sys

root = Path(__file__).resolve().parents[1]
assets = json.loads((root / 'ThirdParty/bundled-backgrounds.json').read_text())['assets']
errors = []
paths = set()
presets = set()
for asset in assets:
    path = asset['path']
    preset = asset['preset']
    if path != f'BG/BUNDLED/{preset}.png' or path in paths or preset in presets:
        errors.append(f'Invalid or duplicate asset: {path}')
        continue
    paths.add(path)
    presets.add(preset)
    try:
        data = (root / path).read_bytes()
        if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise ValueError('invalid PNG header')
        if struct.unpack('>II', data[16:24]) != (asset['width'], asset['height']):
            raise ValueError('dimensions differ from manifest')
        if hashlib.sha256(data).hexdigest() != asset['sha256']:
            raise ValueError('source bytes differ from manifest')
    except (OSError, ValueError) as error:
        errors.append(f'{path}: {error}')
actual = {str(p.relative_to(root)) for p in (root / 'BG/BUNDLED').glob('*.png')}
if len(assets) != 10 or actual != paths:
    errors.append('Expected exactly the ten registered PNGs')
source = (root / 'Sources/Features/Host/KantaBuiltInVisuals.swift').read_text()
static_cases = source.split('// Ten animated presets.')[0]
for preset in presets:
    if f'    case {preset}\n' not in static_cases:
        errors.append(f'Missing stable static selection: {preset}')
if 'subdirectory: "BUNDLED"' not in source:
    errors.append('Bundle lookup must match the folder reference')
project = (root / 'project.yml').read_text()
if 'path: BG/BUNDLED\n        type: folder\n        buildPhase: resources' not in project:
    errors.append('Missing app resource folder reference')
if errors:
    sys.exit('\n'.join(errors))
print('Bundled backgrounds passed: 10 original PNGs, hashes, dimensions and app resource wiring.')
