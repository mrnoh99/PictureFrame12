#!/usr/bin/env python3
"""
Generate app icon PNGs for PictureFrame12 using the original PictureFrame
app icon as the source.

Source PNG search order (first match wins):
  1. AppIcon-source.png         -- manually placed next to this script
  2. ../pictureframe/PictureFrame/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
  3. ../PictureFrame/PictureFrame/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

Requires macOS sips (pre-installed on every Mac, no extra dependencies).

Usage:
  cd /path/to/pictureframe12
  python3 generate_icons.py
"""

import os
import sys
import subprocess

OUTPUT_DIR = "PictureFrame12/Assets.xcassets/AppIcon.appiconset"

SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]

# Locations checked for the 1024x1024 source PNG, in order of preference.
# Assumes both repos are siblings in the same parent directory (common layout).
SOURCE_CANDIDATES = [
    "AppIcon-source.png",
    "../pictureframe/PictureFrame/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    "../PictureFrame/PictureFrame/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
]


def find_source():
    for path in SOURCE_CANDIDATES:
        if os.path.isfile(path):
            return path
    return None


def main():
    src = find_source()
    if src is None:
        print("ERROR: Could not find source icon. Tried:")
        for c in SOURCE_CANDIDATES:
            print(f"  {c}")
        print()
        print("Fix: place the 1024x1024 PNG from the original PictureFrame")
        print("     app icon next to this script and name it AppIcon-source.png,")
        print("     then re-run.")
        sys.exit(1)

    print(f"Source: {os.path.abspath(src)}")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    ok = True
    for size in SIZES:
        out = os.path.join(OUTPUT_DIR, f"icon_{size}.png")
        result = subprocess.run(
            ["sips", "-z", str(size), str(size), src, "--out", out],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"  FAIL  icon_{size}.png  -- {result.stderr.strip()}")
            ok = False
        else:
            print(f"  OK    icon_{size}.png  ({size}x{size})")

    if not ok:
        sys.exit(1)

    print()
    print("All icons generated. Commit them with:")
    print(f"  git add {OUTPUT_DIR}/")
    print("  git commit -m 'Add app icon PNGs from original PictureFrame'")
    print("  git push -u origin claude/pictureframe-ios12-compat-d0gej2")


if __name__ == "__main__":
    main()
