#!/usr/bin/env python3
"""Generate ScribeInk placeholder icons (app icon and menu-bar glyph).

Usage: python3 scripts/generate-placeholder-icons.py --font /path/to/SerifBold.ttf

Writes every PNG listed in AppIcon.appiconset/Contents.json (existing file names) and the
black-on-transparent template glyph for menuBarIcon.imageset. Needs Pillow. These are
placeholders until the real artwork exists.
"""
import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(ROOT, "VoiceInk", "Assets.xcassets")
BG = (0x10, 0x1F, 0x26, 255)
ACCENT = (0xE4, 0x56, 0x30, 255)
WHITE = (255, 255, 255, 255)
SUPER = 4  # supersampling factor for smooth edges


def fit_font(path, text, box_w, box_h):
    size = box_h
    while size > 4:
        font = ImageFont.truetype(path, size)
        l, t, r, b = font.getbbox(text)
        if r - l <= box_w and b - t <= box_h:
            return font
        size -= 2
    return ImageFont.truetype(path, 4)


def draw_si(draw, canvas, font_path, fill, width_frac, height_frac, dot=None):
    """Centre 'SI' in a canvas; return the bbox of the I for the accent dot."""
    box_w, box_h = int(canvas * width_frac), int(canvas * height_frac)
    font = fit_font(font_path, "SI", box_w, box_h)
    l, t, r, b = font.getbbox("SI")
    x = (canvas - (r - l)) / 2 - l
    y = (canvas - (b - t)) / 2 - t
    draw.text((x, y), "SI", font=font, fill=fill)
    i_l, i_t, i_r, i_b = font.getbbox("I")
    s_adv = font.getlength("S")
    i_right = x + s_adv + i_r
    i_top = y + i_t
    return i_right, i_top, b - t


def app_icon(size, font_path):
    big = size * SUPER
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * 0.225), fill=BG)
    i_right, i_top, glyph_h = draw_si(d, big, font_path, WHITE, 0.56, 0.40)
    r = big * 0.045
    cx, cy = i_right + r * 0.4, i_top - r * 0.2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=ACCENT)
    return img.resize((size, size), Image.LANCZOS)


def menu_glyph(size, font_path):
    big = size * SUPER
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_si(d, big, font_path, (0, 0, 0, 255), 0.90, 0.70)
    return img.resize((size, size), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True, help="path to a serif bold .ttf")
    args = ap.parse_args()

    appiconset = os.path.join(ASSETS, "AppIcon.appiconset")
    with open(os.path.join(appiconset, "Contents.json")) as f:
        images = json.load(f)["images"]
    sizes = {}
    for im in images:
        sizes[im["filename"]] = int(im["expected-size"])
    for name, px in sorted(sizes.items()):
        app_icon(px, args.font).save(os.path.join(appiconset, name))
        print(f"AppIcon {name} {px}x{px}")

    menu_dir = os.path.join(ASSETS, "menuBarIcon.imageset")
    with open(os.path.join(menu_dir, "Contents.json")) as f:
        menu_images = json.load(f)["images"]
    # The imageset lists no pixel size; keep the existing 750x750 canvas.
    for im in menu_images:
        menu_glyph(750, args.font).save(os.path.join(menu_dir, im["filename"]))
        print(f"menuBarIcon {im['filename']} 750x750")


if __name__ == "__main__":
    main()
