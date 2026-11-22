#!/usr/bin/env python3
"""
Generatore di sfondi per labwc-q4os.

Crea tre wallpaper astratti, moderni e coerenti con le palette dei temi:
  * nordic-cobalt  (blu profondo / ardesia)
  * muted-crimson  (bordeaux / terracotta desaturato)
  * sage-emerald   (verde salvia / petrolio)

Tutto viene disegnato localmente con Pillow: nessun download, nessun link
esterno che possa rompersi. Ogni sfondo contiene la firma discreta
"reverseloop-dev" in basso a destra.

Uso:
    ./generate-wallpapers.py --output ~/.local/share/labwc-q4os/wallpapers
    ./generate-wallpapers.py --width 1280 --height 720 --output preview
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    RESAMPLE = getattr(Image, "Resampling", Image).BICUBIC
except ImportError:  # pragma: no cover
    sys.stderr.write(
        "Pillow non trovato. Installare con: sudo apt install python3-pil\n"
    )
    sys.exit(1)


THEMES = {
    "nordic-cobalt": {
        "seed": 1107,
        "base_top": "#070d1a",
        "base_bottom": "#1e293b",
        "glows": ["#1d4ed8", "#0ea5e9", "#3b82f6"],
        "accent": "#60a5fa",
        "accent_soft": "#93c5fd",
        "line": "#38bdf8",
        "signature": "#dbeafe",
    },
    "muted-crimson": {
        "seed": 2203,
        "base_top": "#120b0d",
        "base_bottom": "#2b1e20",
        "glows": ["#7f1d1d", "#9f3a3f", "#c0565b"],
        "accent": "#d98a8e",
        "accent_soft": "#e8b4b7",
        "line": "#c0565b",
        "signature": "#f4e4e4",
    },
    "sage-emerald": {
        "seed": 3301,
        "base_top": "#08110f",
        "base_bottom": "#1b2624",
        "glows": ["#1f5c4a", "#2f7d63", "#4d9375"],
        "accent": "#6fbf9a",
        "accent_soft": "#a3d9bf",
        "line": "#4d9375",
        "signature": "#e3f1ea",
    },
}


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def make_gradient(width: int, height: int, top: str, bottom: str) -> Image.Image:
    """Gradiente diagonale morbido, calcolato in piccolo e poi ingrandito."""
    sw, sh = 320, 180
    top_rgb, bottom_rgb = hex_rgb(top), hex_rgb(bottom)
    small = Image.new("RGB", (sw, sh))
    px = small.load()
    assert px is not None
    for y in range(sh):
        for x in range(sw):
            # diagonale: piu' peso alla verticale, con una leggera deriva a destra
            t = min(1.0, max(0.0, (y / (sh - 1)) * 0.78 + (x / (sw - 1)) * 0.22))
            # curva morbida per evitare una transizione piatta
            t = t * t * (3.0 - 2.0 * t)
            px[x, y] = (
                int(lerp(top_rgb[0], bottom_rgb[0], t)),
                int(lerp(top_rgb[1], bottom_rgb[1], t)),
                int(lerp(top_rgb[2], bottom_rgb[2], t)),
            )
    return small.resize((width, height), RESAMPLE)


def add_glow(
    canvas: Image.Image,
    cx: float,
    cy: float,
    radius: float,
    color: str,
    strength: float,
) -> None:
    """Macchia di luce radiale con falloff morbido (mesh gradient)."""
    width, height = canvas.size
    sw, sh = 220, 124
    mask = Image.new("L", (sw, sh), 0)
    mpx = mask.load()
    assert mpx is not None
    rgb = hex_rgb(color)
    for y in range(sh):
        for x in range(sw):
            dx = (x / (sw - 1)) * width - cx
            dy = (y / (sh - 1)) * height - cy
            dist = math.hypot(dx, dy) / radius
            if dist >= 1.0:
                continue
            # falloff gaussiano: centro luminoso, bordo invisibile
            alpha = math.exp(-4.2 * dist * dist) * strength
            mpx[x, y] = max(0, min(255, int(alpha * 255)))

    mask = mask.resize((width, height), RESAMPLE)
    layer = Image.new("RGBA", (width, height), (*rgb, 0))
    layer.putalpha(mask)
    canvas.alpha_composite(layer)


def add_geometry(
    canvas: Image.Image, width: int, height: int, theme: dict, rng: random.Random
) -> None:
    """Anelli, archi e linee sottili: pochi elementi, molto spazio negativo."""
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    accent = hex_rgb(theme["accent"])
    soft = hex_rgb(theme["accent_soft"])
    line = hex_rgb(theme["line"])

    # grande arco decentrato
    r = int(height * 0.72)
    cx = int(width * 0.86)
    cy = int(height * 0.12)
    draw.arc(
        (cx - r, cy - r, cx + r, cy + r),
        start=105,
        end=255,
        fill=(*accent, 44),
        width=max(2, width // 900),
    )
    # secondo arco, piu' ampio e tenue
    r2 = int(height * 0.96)
    draw.arc(
        (cx - r2, cy - r2, cx + r2, cy + r2),
        start=120,
        end=220,
        fill=(*soft, 22),
        width=max(1, width // 1600),
    )

    # cerchio pieno traslucido in basso a sinistra
    r3 = int(height * 0.34)
    cx3, cy3 = int(width * 0.14), int(height * 0.92)
    draw.ellipse(
        (cx3 - r3, cy3 - r3, cx3 + r3, cy3 + r3),
        fill=(*line, 12),
    )

    # linee diagonali sottili
    for i in range(3):
        offset = int(width * (0.06 + i * 0.035))
        y0 = int(height * 0.18 + i * height * 0.06)
        draw.line(
            (offset, y0, offset + int(width * 0.42), y0 - int(height * 0.16)),
            fill=(*soft, 18 + i * 5),
            width=1,
        )

    # griglia di punti molto discreta (texture da studio grafico)
    spacing = max(28, width // 64)
    for y in range(spacing, height, spacing):
        for x in range(spacing, width, spacing):
            # fade verso il centro per non affollare
            nx, ny = x / width, y / height
            if 0.18 < nx < 0.82 and 0.18 < ny < 0.82:
                continue
            draw.ellipse((x, y, x + 1, y + 1), fill=(*soft, 20))

    # piccoli punti luminosi sparsi
    for _ in range(14):
        x = rng.randint(int(width * 0.05), int(width * 0.95))
        y = rng.randint(int(height * 0.05), int(height * 0.85))
        radius = rng.choice((1, 1, 2))
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=(*accent, rng.randint(28, 70)),
        )

    canvas.alpha_composite(overlay.filter(ImageFilter.GaussianBlur(0.4)))


def add_vignette(canvas: Image.Image, width: int, height: int) -> None:
    # maschera radiale scura ai bordi
    sw, sh = 240, 135
    mask = Image.new("L", (sw, sh), 0)
    mpx = mask.load()
    assert mpx is not None
    for y in range(sh):
        for x in range(sw):
            nx = (x / (sw - 1)) * 2 - 1
            ny = (y / (sh - 1)) * 2 - 1
            d = min(1.0, math.hypot(nx * 0.92, ny * 0.92))
            mpx[x, y] = int((d**2.4) * 150)
    mask = mask.resize((width, height), RESAMPLE)
    dark = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dark.putalpha(mask)
    canvas.alpha_composite(dark)


def add_grain(canvas: Image.Image, rng: random.Random) -> None:
    width, height = canvas.size
    noise = Image.effect_noise((width, height), 24).convert("L")
    grain = Image.merge(
        "RGBA",
        (
            noise,
            noise,
            noise,
            Image.new("L", (width, height), 8),
        ),
    )
    canvas.alpha_composite(grain)


def find_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/inter/Inter-Regular.ttf",
        "/usr/share/fonts/opentype/inter/Inter-Regular.otf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10
        return ImageFont.load_default()


def text_width(draw: ImageDraw.ImageDraw, text: str, font, spacing: int) -> int:
    total = 0
    for ch in text:
        try:
            box = draw.textbbox((0, 0), ch, font=font)
            total += box[2] - box[0]
        except Exception:
            total += spacing
    return total + spacing * (len(text) - 1)


def add_signature(canvas: Image.Image, width: int, height: int, theme: dict) -> None:
    """Firma discreta in basso a destra: reverseloop-dev."""
    text = "reverseloop-dev"
    size = max(14, width // 118)
    font = find_font(size)
    spacing = max(1, size // 12)
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    rgb = hex_rgb(theme["signature"])
    accent = hex_rgb(theme["accent"])

    margin_x = max(26, width // 44)
    margin_y = max(18, height // 46)
    tw = text_width(draw, text, font, spacing)
    try:
        box = draw.textbbox((0, 0), text, font=font)
        th = box[3] - box[1]
    except Exception:
        th = size

    x = width - margin_x - tw
    y = height - margin_y - th

    # pallino accent + firma
    dot_r = max(2, size // 7)
    draw.ellipse(
        (x - size - dot_r, y + th // 2 - dot_r, x - size + dot_r, y + th // 2 + dot_r),
        fill=(*accent, 150),
    )
    cursor = x
    for ch in text:
        draw.text((cursor, y), ch, font=font, fill=(*rgb, 105))
        try:
            box = draw.textbbox((0, 0), ch, font=font)
            cursor += (box[2] - box[0]) + spacing
        except Exception:
            cursor += size

    canvas.alpha_composite(overlay)


def render(theme_name: str, width: int, height: int, output: str) -> str:
    theme = THEMES[theme_name]
    rng = random.Random(theme["seed"])

    canvas = make_gradient(width, height, theme["base_top"], theme["base_bottom"]).convert(
        "RGBA"
    )

    # glow principali: uno grande, due di supporto
    add_glow(canvas, width * 0.78, height * 0.22, width * 0.55, theme["glows"][0], 0.52)
    add_glow(canvas, width * 0.18, height * 0.80, width * 0.42, theme["glows"][1], 0.34)
    add_glow(canvas, width * 0.55, height * 0.62, width * 0.30, theme["glows"][2], 0.20)

    add_geometry(canvas, width, height, theme, rng)
    add_grain(canvas, rng)
    add_vignette(canvas, width, height)
    add_signature(canvas, width, height, theme)

    os.makedirs(output, exist_ok=True)
    path = os.path.join(output, f"{theme_name}.png")
    canvas.convert("RGB").save(path, "PNG", optimize=True)
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera gli sfondi di labwc-q4os")
    parser.add_argument("--output", default="wallpapers", help="cartella di destinazione")
    parser.add_argument("--width", type=int, default=2560)
    parser.add_argument("--height", type=int, default=1440)
    parser.add_argument(
        "--only",
        choices=sorted(THEMES),
        action="append",
        help="genera solo il tema indicato (ripetibile)",
    )
    args = parser.parse_args()

    if args.width < 640 or args.height < 360:
        parser.error("risoluzione minima 640x360")

    selected = args.only or list(THEMES)
    for name in selected:
        path = render(name, args.width, args.height, args.output)
        print(f"generato: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
