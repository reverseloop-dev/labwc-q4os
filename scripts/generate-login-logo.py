#!/usr/bin/env python3
"""
generate-login-logo.py - pattern del logo reverseloop-dev per SDDM.

Per ogni tema in --themes-dir legge theme.conf e genera "logo-pattern.png":
un solo logo grande, centrato, con 2 cm di margine a sinistra e a destra,
tinto con logo_tint (o accent) e con la stessa trasparenza di sempre. Tutto
deterministico (seed fisso per tema): due esecuzioni producono lo stesso logo.

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

# Un solo logo grande, centrato, con 2 cm di margine a sinistra e a destra.
LOGIN_MARGIN_CM = 2.0
CSS_DPI = 96.0



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


def build_pattern(
    mask: Image.Image, tint: str, theme: str, width: int, height: int
) -> Image.Image:
    rng = random.Random(THEME_SEEDS.get(theme, 4242))
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    # Un solo logo grande, centrato: 2 cm di margine a sinistra e a destra.
    # Se cosi' fosse troppo alto, si riduce per stare dentro i margini.
    margin = int(round(width * LOGIN_MARGIN_CM * CSS_DPI / 2.54 / 1920))
    max_w = max(1, width - 2 * margin)
    max_h = max(1, height - 2 * margin)
    scale = min(max_w / mask.width, max_h / mask.height)
    logo_w = max(1, int(mask.width * scale))
    logo_h = max(1, int(mask.height * scale))
    x = (width - logo_w) // 2
    y = (height - logo_h) // 2
    alpha = 0.05 + rng.random() * 0.06
    logo = tinted_logo(mask, tint, logo_w, alpha)
    canvas.alpha_composite(logo, (x, y))
    if os.environ.get("LABWC_Q4OS_LOGIN_DEBUG") == "1":
        print(f"pattern {theme}: 1 logo -> ({x}, {y}, {logo_w}, {logo_h})", file=sys.stderr)
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
