#!/usr/bin/env python3
"""Export canonical astronomy code/content without altering either app's catalog."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('sightline', type=Path)
p.add_argument('--check', action='store_true')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
source = root / 'Packages/CelestialKit'
destination = a.sightline / 'Vendor/CelestialKit'
if not (a.sightline / 'Sources/Sightline').is_dir():
    raise SystemExit('Expected a Sightline source checkout')

def tracked_files(directory):
    return {str(f.relative_to(directory)): f for f in directory.rglob('*')
            if f.is_file() and not any(v in f.parts for v in ['.build', '.DS_Store', '.swiftpm'])
            and f.name != 'UPSTREAM.json'}

files = tracked_files(source)
manifest = {n: hashlib.sha256(f.read_bytes()).hexdigest() for n, f in sorted(files.items())}
version = json.loads((source / 'Sources/CelestialKit/Resources/astronomy/catalog.json').read_text())['version']
upstream = dict(source='https://github.com/ykopp/starfolio-wallpaper', path='Packages/CelestialKit', version=version, files=manifest)
extras = set(tracked_files(destination)) - set(files)
if extras:
    raise SystemExit('Review stale or extra snapshot files before syncing: ' + ', '.join(sorted(extras)))
if a.check:
    for n, h in manifest.items():
        f = destination / n
        if not f.is_file() or hashlib.sha256(f.read_bytes()).hexdigest() != h:
            raise SystemExit('Out of sync: ' + n)
    if json.loads((destination / 'UPSTREAM.json').read_text()) != upstream:
        raise SystemExit('UPSTREAM.json is out of sync')
    print('Shared component and astronomy assets are identical:', len(files), 'files')
else:
    destination.mkdir(parents=True, exist_ok=True)
    for n, f in files.items():
        target = destination / n
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, target)
    (destination / 'UPSTREAM.json').write_text(json.dumps(upstream, indent=2) + '\n')
    print('Updated', destination)
