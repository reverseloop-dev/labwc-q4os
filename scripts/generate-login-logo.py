#!/usr/bin/env python3
"""
generate-login-logo.py - logo reverseloop-dev "tono su tono" per SDDM.

Per ogni tema in --themes-dir legge theme.conf e genera logo.png:
monocromatico, tinto con logo_tint (o accent) e semitrasparente, come il logo
al centro degli sfondi del desktop. Il file viene usato da Main.qml.

Uso:
  generate-login-logo.py --themes-dir configs/sddm/themes
  generate-login-logo.py --themes-dir /usr/share/labwc-q4os/login-themes \
      --logo configs/logo/rl-dev.png --alpha 0.13 --width 640
"""

from __future__ import annotations

import argparse
import os
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


def make_logo(mask: Image.Image, tint: str, alpha: float, width: int) -> Image.Image:
    target_w = max(120, width)
    target_h = max(1, int(mask.height * target_w / mask.width))
    resized = mask.resize((target_w, target_h), RESAMPLE)
    rgb = hex_rgb(tint)
    logo = Image.new("RGBA", (target_w, target_h), (*rgb, 0))
    logo.putalpha(resized.point(lambda v: int(v * alpha)))
    return logo


def main() -> int:
    parser = argparse.ArgumentParser(description="Logo tono su tono per i temi login")
    parser.add_argument("--themes-dir", required=True, help="cartella con i temi SDDM")
    parser.add_argument("--logo", default=None, help="immagine sorgente del logo")
    parser.add_argument("--alpha", type=float, default=0.13, help="opacita' massima (0-1)")
    parser.add_argument("--width", type=int, default=640, help="larghezza in pixel")
    args = parser.parse_args()

    source = find_logo(args.logo)
    if not source:
        print("Logo reverseloop-dev non trovato: logo login non generato.", file=sys.stderr)
        return 1
    try:
        src = Image.open(source)
        src.load()
    except OSError as error:
        print(f"Logo non leggibile ({error}): logo login non generato.", file=sys.stderr)
        return 1

    mask = monochrome_mask(src)
    if not mask.getbbox():
        print("Logo vuoto: logo login non generato.", file=sys.stderr)
        return 1

    alpha = max(0.0, min(1.0, args.alpha))
    generated = 0
    for name in sorted(os.listdir(args.themes_dir)):
        theme_dir = os.path.join(args.themes_dir, name)
        conf_path = os.path.join(theme_dir, "theme.conf")
        if not os.path.isdir(theme_dir) or not os.path.isfile(conf_path):
            continue
        conf = read_conf(conf_path)
        tint = conf.get("logo_tint") or conf.get("accent") or conf.get("accent_soft") or "ffffff"
        logo = make_logo(mask, tint, alpha, args.width)
        out = os.path.join(theme_dir, "logo.png")
        logo.save(out, "PNG", optimize=True)
        generated += 1
        print(f"logo login: {out} (tinta #{tint.lstrip('#')})")

    if generated == 0:
        print("Nessun tema con theme.conf trovato.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
