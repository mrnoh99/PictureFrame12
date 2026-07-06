#!/usr/bin/env python3
"""
Generates all required iOS app icon PNGs for PictureFrame12.
Run once from the project root:
    python3 generate_icons.py
Then commit the generated PNGs and rebuild in Xcode.
"""
import os, struct, zlib

def make_png(size):
    s = size
    rows = bytearray()
    for y in range(s):
        rows.append(0)  # filter: None
        for x in range(s):
            rows.extend(pixel(x, y, s))
    compressed = zlib.compress(bytes(rows), 9)

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)

    ihdr = struct.pack('>IIBBBBB', s, s, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', compressed) + chunk(b'IEND', b'')

def pixel(x, y, s):
    margin = max(1, int(s * 0.11))
    border = max(1, int(s * 0.07))
    in_outer = margin <= x < s - margin and margin <= y < s - margin
    in_inner = (margin + border <= x < s - margin - border and
                margin + border <= y < s - margin - border)
    if not in_outer:
        return (22, 32, 58)      # dark navy background
    elif not in_inner:
        return (218, 176, 68)    # gold frame border
    else:
        return (38, 50, 76)      # darker mat inside

SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]

script_dir = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(script_dir, 'PictureFrame12', 'Assets.xcassets', 'AppIcon.appiconset')
os.makedirs(out_dir, exist_ok=True)

for s in SIZES:
    data = make_png(s)
    name = 'icon_' + str(s) + '.png'
    with open(os.path.join(out_dir, name), 'wb') as f:
        f.write(data)
    print('  ' + name + '  (' + str(len(data)) + ' bytes)')

print('Done. Commit the PNGs, then rebuild in Xcode.')
