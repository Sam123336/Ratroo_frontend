#!/usr/bin/env python3
"""Derive the app's icon assets from the master logo.

    python3 tool/build_brand_assets.py ~/Ratroo.png
    python3 tool/build_brand_assets.py modes bus=~/Bus.png rail=~/Rail.png \
        ferry=~/ferry.png tram=~/term.png

The master is a 1254x1254 PNG with no alpha channel, so everything outside the
rounded square is solid black. Shipping that as the launcher icon puts black
wedges in the corners, because Android and iOS apply their own mask on top of
whatever they are given. Each output below exists to avoid that.

  ratroo_icon.png             full-bleed white, for iOS and legacy Android.
                              The rounding is left to the platform.
  ratroo_icon_foreground.png  the same mark inset to Android's adaptive-icon
                              safe zone, which scales the foreground by 1.5x
                              and crops. Opaque white, paired with a white
                              background layer.
  ratroo_logo.png             the mark alone on transparency, for use inside
                              the app where the surface is not white.

Requires Pillow. Re-run this whenever the master logo changes.
"""
import sys
from pathlib import Path

from PIL import Image

# Anything this dark is the surround, not artwork: the mark is orange on white.
DARK = 120
# Blue channel of the mark at full strength, used to recover coverage from a
# pixel that was composited onto white.
MARK_MIN_CHANNEL = 23
SIZE = 1024
# Android scales the adaptive foreground by 1.5x, so the mark must sit inside
# the middle ~66% or it gets cropped.
SAFE_ZONE = 0.46
# Mode thumbnails render at 64pt; 256px covers 3x screens.
MODE_SIZE = 256

OUT = Path(__file__).resolve().parent.parent / 'assets' / 'brand'


def whiten_surround(image: Image.Image) -> Image.Image:
    """Replace the black surround with white, leaving the artwork alone."""
    result = image.convert('RGB')
    pixels = result.load()
    width, height = result.size

    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            if r < DARK and g < DARK and b < DARK:
                pixels[x, y] = (255, 255, 255)

    return result


def mark_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of the orange mark alone.

    Found by saturation, not by brightness: the master's rounded tile carries a
    soft shadow that a brightness threshold treats as artwork, which cropped to
    the whole tile and left the R looking shrunken inside it.
    """
    saturation = image.convert('HSV').getchannel('S')
    mask = saturation.point(lambda value: 255 if value > 60 else 0)
    box = mask.getbbox()
    if box is None:
        raise SystemExit('Found no mark in the master image.')
    return box


def to_transparent(image: Image.Image) -> Image.Image:
    """Lift the mark off its white field into an alpha channel.

    A pixel is the mark composited onto white, so its coverage is how far the
    weakest channel has been pulled down from 255.
    """
    source = image.convert('RGB')
    result = Image.new('RGBA', source.size)
    read, write = source.load(), result.load()
    width, height = source.size
    span = 255 - MARK_MIN_CHANNEL

    for y in range(height):
        for x in range(width):
            r, g, b = read[x, y]
            alpha = min(255, round((255 - min(r, g, b)) * 255 / span))
            write[x, y] = (r, g, b, alpha)

    return result


def build_modes(pairs: list[str]) -> None:
    """Square thumbnails for the home screen's mode buttons.

        python3 tool/build_brand_assets.py modes bus=~/Bus.png tram=~/term.png

    The source photos are 1.5-2.5 MB each. They are centre-cropped to a square
    and written as small JPEGs, because bundling the originals would add ~8 MB
    to the app for four circles 64 points wide.
    """
    OUT.mkdir(parents=True, exist_ok=True)

    for pair in pairs:
        mode, _, source = pair.partition('=')
        if not source:
            raise SystemExit(f'Expected mode=path, got {pair!r}')

        photo = Image.open(Path(source).expanduser()).convert('RGB')
        side = min(photo.size)
        left = (photo.width - side) // 2
        top = (photo.height - side) // 2
        square = photo.crop((left, top, left + side, top + side))
        square = square.resize((MODE_SIZE, MODE_SIZE), Image.LANCZOS)

        target = OUT / f'mode_{mode}.jpg'
        square.save(target, 'JPEG', quality=85, optimize=True)
        print(f'  {target.name}: {MODE_SIZE}x{MODE_SIZE} ({target.stat().st_size // 1024} KB)')


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)

    if sys.argv[1] == 'modes':
        build_modes(sys.argv[2:])
        return

    master = Image.open(Path(sys.argv[1]).expanduser())
    OUT.mkdir(parents=True, exist_ok=True)

    flat = whiten_surround(master)

    # 1. Full bleed: crop off the surround entirely, then fill the canvas.
    inner = flat.crop(mark_bounds(flat)).convert('RGB')
    icon = Image.new('RGB', (SIZE, SIZE), 'white')
    scaled = _fit(inner, int(SIZE * 0.58))
    icon.paste(scaled, _centre(scaled, SIZE))
    icon.save(OUT / 'ratroo_icon.png')

    # 2. Adaptive foreground: same mark, inside the safe zone.
    foreground = Image.new('RGB', (SIZE, SIZE), 'white')
    inset = _fit(inner, int(SIZE * SAFE_ZONE))
    foreground.paste(inset, _centre(inset, SIZE))
    foreground.save(OUT / 'ratroo_icon_foreground.png')

    # 3. In-app mark on transparency.
    to_transparent(inner).save(OUT / 'ratroo_logo.png')

    for name in ('ratroo_icon.png', 'ratroo_icon_foreground.png', 'ratroo_logo.png'):
        written = Image.open(OUT / name)
        print(f'  {name}: {written.size[0]}x{written.size[1]} {written.mode}')


def _fit(image: Image.Image, target: int) -> Image.Image:
    ratio = target / max(image.size)
    size = (round(image.width * ratio), round(image.height * ratio))
    return image.resize(size, Image.LANCZOS)


def _centre(image: Image.Image, canvas: int) -> tuple[int, int]:
    return ((canvas - image.width) // 2, (canvas - image.height) // 2)


if __name__ == '__main__':
    main()
