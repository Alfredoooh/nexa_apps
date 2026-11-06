#!/usr/bin/env python3
"""Idempotently register flutter_svg and BrowseIt's Phosphor SVG assets."""
from pathlib import Path
import re

path = Path('pubspec.yaml')
if not path.exists():
    raise SystemExit('Run this script from the Flutter project root (pubspec.yaml not found).')
text = path.read_text(encoding='utf-8')

# Add flutter_svg under dependencies without replacing existing dependencies.
if not re.search(r'^\s{2}flutter_svg\s*:', text, flags=re.M):
    match = re.search(r'^dependencies:\s*$', text, flags=re.M)
    if not match:
        raise SystemExit('Could not find the top-level dependencies: section.')
    next_top = re.search(r'^\S[^\n]*:\s*$', text[match.end():], flags=re.M)
    insert_at = match.end() + (next_top.start() if next_top else len(text[match.end():]))
    block = text[match.start():insert_at]
    if block and not block.endswith('\n'):
        block += '\n'
        insert_at = match.start() + len(block)
        text = text[:match.start()] + block + text[insert_at:]
    text = text[:insert_at] + '  flutter_svg: ^2.3.2\n' + text[insert_at:]

# Add the entire icon directory to flutter.assets, preserving existing asset entries.
flutter_match = re.search(r'^flutter:\s*$', text, flags=re.M)
if not flutter_match:
    raise SystemExit('Could not find the top-level flutter: section.')
rest = text[flutter_match.end():]
next_top = re.search(r'^\S[^\n]*:\s*$', rest, flags=re.M)
flutter_end = flutter_match.end() + (next_top.start() if next_top else len(rest))
flutter_block = text[flutter_match.start():flutter_end]
asset_line = '    - assets/icons/phosphor/'
if not re.search(r'^\s{4}-\s*[\"\']?assets/icons/phosphor/?[\"\']?\s*$', flutter_block, flags=re.M):
    assets_match = re.search(r'^  assets:\s*$', flutter_block, flags=re.M)
    if assets_match:
        after_assets = flutter_block[assets_match.end():]
        next_flutter_key = re.search(r'^  [A-Za-z0-9_-]+\s*:', after_assets, flags=re.M)
        assets_end = assets_match.end() + (next_flutter_key.start() if next_flutter_key else len(after_assets))
        insert = '\n' + asset_line + '\n'
        flutter_block = flutter_block[:assets_end].rstrip('\n') + insert + flutter_block[assets_end:]
    else:
        if flutter_block and not flutter_block.endswith('\n'):
            flutter_block += '\n'
        flutter_block += '  assets:\n' + asset_line + '\n'
    text = text[:flutter_match.start()] + flutter_block + text[flutter_end:]

path.write_text(text, encoding='utf-8')
print('pubspec.yaml updated: flutter_svg + assets/icons/phosphor/')
