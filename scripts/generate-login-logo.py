#!/usr/bin/env python3
"""
generate-login-logo.py - pattern del logo reverseloop-dev per SDDM.

Per ogni tema in --themes-dir legge theme.conf e genera "logo-pattern.png":
quattro copie dello stesso logo, ognuna con dimensione e posizione diversa,
tinte con logo_tint (o accent), distribuite sullo sfondo senza sovrapposizioni
e senza coprire le zone dove stanno card, form e orologio. Tutto deterministico
(seed fisso per tema): due esecuzioni producono lo stesso pattern.

Uso:
  generate-login-logo.py --themes-dir configs/sddm/themes
  generate-login-logo.py --themes-dir /usr/share/labwc-q4os/login-themes \
      --logo configs/logo/rl-dev.png --width 1920 --height 1080
"""

from __future__ import annotations

import argparse
import os
import random
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("python3-pil mancante: impossibile generare il logo login.", file=sys.stderr)
    raise SystemExit(1)

try:
    RESAMPLE = Image.Resampling.LANCZOS
except AttributeError:  # Pillow < 9.1
    RESAMPLE = Image.LANCZOS

THEME_SEEDS = {"nordic-cobalt": 1301, "muted-crimson": 2203, "sage-emerald": 3301}

# Quattro loghi, dal piu' grande al piu' piccolo: frazioni della larghezza.
LOGO_SIZES = (0.16, 0.115, 0.085, 0.06)

# Zone da lasciare libere (frazioni di larghezza/altezza): card centrale,
# form a destra dello Split Studio, dock in basso del Bottom Dock.
FORBIDDEN = {
    "default": [(0.32, 0.18, 0.68, 0.86)],
    "muted-crimson": [(0.42, 0.20, 0.86, 0.80)],
    "sage-emerald": [(0.28, 0.00, 0.72, 0.22), (0.08, 0.62, 0.92, 0.98)],
}



def find_logo(explicit: str | None) -> str | None:
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        explicit or "",
        os.environ.get("LABWC_Q4OS_LOGO", ""),
        os.path.join(os.path.dirname(here), "logo", "rl-dev.png"),
        os.path.join(os.path.dirname(here), "configs", "logo", "rl-dev.png"),
        os.path.join(here, "rl-dev.png"),
    ]
    for path in candidates:
        if path and os.path.isfile(path):
            return path
    return None


def read_conf(path: str) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        with open(path, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                values[key.strip().lower()] = value.strip().strip('"').strip("'")
    except OSError:
        return values
    return values


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    if len(value) != 6:
        return (255, 255, 255)
    try:
        return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]
    except ValueError:
        return (255, 255, 255)


def monochrome_mask(src: Image.Image) -> Image.Image:
    """Sagoma del logo: scuro -> pieno, chiaro -> trasparente."""
    src = src.convert("RGBA")
    sw, sh = src.size
    px = src.load()
    mask = Image.new("L", (sw, sh), 0)
    mp = mask.load()
    for y in range(sh):
        for x in range(sw):
            r, g, b, _a = px[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            mp[x, y] = max(0, min(255, int((250 - lum) * 255 / 230)))
    bbox = mask.getbbox()
    if bbox:
        mask = mask.crop(bbox)
    return mask


def tinted_logo(
    mask: Image.Image, tint: str, width: int, alpha: float
) -> Image.Image:
    height = max(1, int(mask.height * width / mask.width))
    resized = mask.resize((width, height), RESAMPLE)
    rgb = hex_rgb(tint)
    logo = Image.new("RGBA", (width, height), (*rgb, 0))
    logo.putalpha(resized.point(lambda v: int(v * alpha)))
    return logo


def overlaps(
    a: tuple[int, int, int, int], b: tuple[int, int, int, int], pad: int
) -> bool:
    return not (
        a[2] + pad <= b[0]
        or b[2] + pad <= a[0]
        or a[3] + pad <= b[1]
        or b[3] + pad <= a[1]
    )


def forbidden_rects(
    theme: str, width: int, height: int
) -> list[tuple[int, int, int, int]]:
    boxes = FORBIDDEN.get(theme, FORBIDDEN["default"])
    return [
        (int(x0 * width), int(y0 * height), int(x1 * width), int(y1 * height))
        for x0, y0, x1, y1 in boxes
    ]


def build_pattern(
    mask: Image.Image, tint: str, theme: str, width: int, height: int
) -> Image.Image:
    rng = random.Random(THEME_SEEDS.get(theme, 4242))
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    placed: list[tuple[int, int, int, int]] = []
    blocked = forbidden_rects(theme, width, height)
    margin = int(width * 0.04)
    pad = int(width * 0.03)
    step = max(8, int(width * 0.02))

    # Quattro loghi di dimensioni diverse, ognuno in una posizione libera
    # scelta a caso sui punti di una griglia fine: mai sovrapposti e mai
    # sopra card, form o orologio.
    sizes = [max(1, int(width * fraction * rng.uniform(0.94, 1.06))) for fraction in LOGO_SIZES]
    for logo_w in sizes:
        logo_h = max(1, int(mask.height * logo_w / mask.width))
        if logo_w > width - 2 * margin or logo_h > height - 2 * margin:
            continue
        spots = [
            (x, y)
            for x in range(margin, width - margin - logo_w + 1, step)
            for y in range(margin, height - margin - logo_h + 1, step)
        ]
        rng.shuffle(spots)
        for spacing in (pad, 0):
            chosen = None
            for x, y in spots:
                box = (x, y, x + logo_w, y + logo_h)
                if any(overlaps(box, other, spacing) for other in placed):
                    continue
                if any(overlaps(box, zone, spacing) for zone in blocked):
                    continue
                chosen = box
                break
            if chosen:
                alpha = 0.05 + rng.random() * 0.06
                logo = tinted_logo(mask, tint, logo_w, alpha)
                canvas.alpha_composite(logo, (chosen[0], chosen[1]))
                placed.append(chosen)
                break
    if os.environ.get("LABWC_Q4OS_LOGIN_DEBUG") == "1":
        print(f"pattern {theme}: {len(placed)} loghi -> {placed}", file=sys.stderr)
    return canvas


def main() -> int:
    parser = argparse.ArgumentParser(description="Pattern logo tono su tono per SDDM")
    parser.add_argument("--themes-dir", required=True, help="cartella con i temi SDDM")
    parser.add_argument("--logo", default=None, help="immagine sorgente del logo")
    parser.add_argument("--width", type=int, default=1920, help="larghezza canvas")
    parser.add_argument("--height", type=int, default=1080, help="altezza canvas")
    args = parser.parse_args()

    source = find_logo(args.logo)
    if not source:
        print("Logo reverseloop-dev non trovato: pattern login non generato.", file=sys.stderr)
        return 1
    try:
        src = Image.open(source)
        src.load()
    except OSError as error:
        print(f"Logo non leggibile ({error}): pattern login non generato.", file=sys.stderr)
        return 1

    mask = monochrome_mask(src)
    if not mask.getbbox():
        print("Logo vuoto: pattern login non generato.", file=sys.stderr)
        return 1

    generated = 0
    for name in sorted(os.listdir(args.themes_dir)):
        theme_dir = os.path.join(args.themes_dir, name)
        conf_path = os.path.join(theme_dir, "theme.conf")
        if not os.path.isdir(theme_dir) or not os.path.isfile(conf_path):
            continue
        conf = read_conf(conf_path)
        tint = conf.get("logo_tint") or conf.get("accent") or conf.get("accent_soft") or "ffffff"
        pattern = build_pattern(mask, tint, name, args.width, args.height)
        out = os.path.join(theme_dir, "logo-pattern.png")
        pattern.save(out, "PNG", optimize=True)
        stale = os.path.join(theme_dir, "logo.png")
        if os.path.isfile(stale):
            os.unlink(stale)
        generated += 1
        print(f"pattern login: {out} (tinta #{tint.lstrip('#')}, {args.width}x{args.height})")

    if generated == 0:
        print("Nessun tema con theme.conf trovato.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
