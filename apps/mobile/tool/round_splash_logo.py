#!/usr/bin/env python3
"""Bake splash-matching rounded corners into logo PNGs.

Native launch (iOS app-open zoom / Android splash) does not use Flutter's
ClipRRect. Fill pixels outside the rounded rect with the splash background
(#080D1A) so corners read as rounded even when alpha is ignored.

Radius matches Flutter SplashColors: inner 20 / logo 88.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

BG = (0x08, 0x0D, 0x1A, 255)
RADIUS_RATIO = 20 / 88


def round_logo(path: Path) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    r = max(1, int(round(min(w, h) * RADIUS_RATIO)))

    # Composite onto splash bg first (handles prior transparency).
    base = Image.new("RGBA", (w, h), BG)
    base.paste(im, (0, 0), im)

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)

    out = Image.new("RGBA", (w, h), BG)
    out.paste(base, (0, 0), mask)
    out.save(path, "PNG")
    print(f"{path}: {w}x{h} r={r}")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    branding = root / "assets" / "branding"
    targets = [Path(t) for t in sys.argv[1:]]
    if not targets:
        targets = [
            branding / "splash_logo_dark.png",
            branding / "splash_logo.png",
        ]
    for t in targets:
        round_logo(t)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
