#!/usr/bin/env python3
"""
generate-icons.py - genera il set di icone SVG coordinato ai temi labwc-q4os.

Nessuna icona scaricata: tutte le forme sono disegnate localmente, quindi il
set e' originale, ridistribuibile e cambia colore insieme al tema.

Uso:
    generate-icons.py --all --themes-dir ~/.local/share/labwc-q4os/themes \
        --output ~/.local/share/labwc-q4os/icons
    generate-icons.py --theme-conf .../nordic-cobalt/theme.conf --output ...
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

CONTEXTS = ("apps", "actions", "status", "places", "mimetypes", "devices")
CONTEXT_NAMES = {
    "apps": "Applications",
    "actions": "Actions",
    "status": "Status",
    "places": "Places",
    "mimetypes": "MimeTypes",
    "devices": "Devices",
}


def parse_theme(path: Path) -> dict[str, str]:
    colors: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'").lstrip("#")
        if value:
            colors[key] = value
    return colors


def svg(colors: dict[str, str], body: str) -> str:
    surface = colors.get("SURFACE", "1e293b")
    bg_alt = colors.get("BG_ALT", "0f172a")
    border = colors.get("BORDER", "334155")
    accent = colors.get("ACCENT", "3b82f6")
    soft = colors.get("ACCENT_SOFT", "60a5fa")
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#{surface}"/>
      <stop offset="1" stop-color="#{bg_alt}"/>
    </linearGradient>
    <linearGradient id="acc" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#{soft}"/>
      <stop offset="1" stop-color="#{accent}"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="120" height="120" rx="28" fill="url(#tile)" stroke="#{border}" stroke-width="2"/>
  <g fill="none" stroke="url(#acc)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">
{body}
  </g>
</svg>
'''


ICONS: dict[str, str] = {
    # Terminale / sviluppo
    "utilities-terminal": '<path d="M28 38h72a8 8 0 0 1 8 8v36a8 8 0 0 1-8 8H28a8 8 0 0 1-8-8V46a8 8 0 0 1 8-8Z" stroke-width="4"/><path d="m40 54 12 10-12 10M60 74h22"/>',
    "applications-development": '<path d="m44 44-18 20 18 20M84 44l18 20-18 20M72 34 56 94"/>',
    "accessories-text-editor": '<path d="M38 20h38l16 16v72H38z"/><path d="M76 20v18h18M50 54h30M50 68h30M50 82h20"/>',
    "x-office-document": '<path d="M38 20h38l16 16v72H38z"/><path d="M76 20v18h18M50 56h28M50 70h28M50 84h18"/>',
    "x-office-spreadsheet": '<rect x="26" y="28" width="76" height="72" rx="6"/><path d="M26 48h76M26 68h76M50 28v72M76 28v72"/>',
    "application-pdf": '<path d="M38 20h38l16 16v72H38z"/><path d="M76 20v18h18"/><text x="50" y="82" font-size="22" font-family="sans-serif" font-weight="700" fill="url(#acc)" stroke="none">PDF</text>',
    "text-x-generic": '<path d="M38 20h38l16 16v72H38z"/><path d="M76 20v18h18M50 56h28M50 70h28"/>',
    "application-x-executable": '<path d="M52 22h24l4 14 13 8 14-6 12 20-11 10v15l11 10-12 20-14-6-13 8-4 14H52l-4-14-13-8-14 6-12-20 11-10V64L9 54l12-20 14 6 13-8z" stroke-width="3"/><circle cx="64" cy="64" r="15" stroke-width="4"/>',
    # File manager / cartelle
    "system-file-manager": '<path d="M20 42h34l9 11h45v42a8 8 0 0 1-8 8H28a8 8 0 0 1-8-8z" stroke-width="4"/><path d="M20 58h88"/>',
    "folder": '<path d="M20 42h34l9 11h45v42a8 8 0 0 1-8 8H28a8 8 0 0 1-8-8z" stroke-width="4"/>',
    "folder-open": '<path d="M20 42h34l9 11h45v10H38a8 8 0 0 0-8 8l-10 32V42Z" stroke-width="4"/><path d="m30 103 10-32h78l-12 32z" stroke-width="4"/>',
    "user-trash": '<path d="M30 42h68M52 42V30h24v12M40 42l6 68h36l6-68M54 56v40M74 56v40"/>',
    # Internet / categoria
    "web-browser": '<circle cx="64" cy="64" r="42" stroke-width="4"/><path d="M22 64h84M64 22c14 12 20 26 20 42S78 94 64 106M64 22c-14 12-20 26-20 42s6 30 20 42"/>',
    "applications-internet": '<circle cx="64" cy="64" r="42" stroke-width="4"/><path d="M22 64h84M64 22c14 12 20 26 20 42S78 94 64 106M64 22c-14 12-20 26-20 42s6 30 20 42"/>',
    "mail-message-new": '<rect x="20" y="34" width="88" height="60" rx="8" stroke-width="4"/><path d="m22 40 42 30 42-30M32 84l24-18M96 84 72 66"/>',
    # Multimedia
    "audio-volume-high": '<path d="M24 52h18l22-18v60L42 76H24z" stroke-width="4"/><path d="M80 50c8 8 8 20 0 28M92 40c15 14 15 34 0 48"/>',
    "audio-volume-muted": '<path d="M24 52h18l22-18v60L42 76H24z" stroke-width="4"/><path d="m82 52 24 24M106 52 82 76"/>',
    "audio-x-generic": '<path d="M52 88V34l40-8v54"/><circle cx="40" cy="90" r="14" stroke-width="4"/><circle cx="80" cy="82" r="14" stroke-width="4"/>',
    "camera-photo": '<path d="M24 42h20l8-10h24l8 10h20v60H24z" stroke-width="4"/><circle cx="64" cy="70" r="20" stroke-width="4"/>',
    "video-x-generic": '<rect x="20" y="34" width="88" height="60" rx="8" stroke-width="4"/><path d="m52 48 24 16-24 16z" fill="url(#acc)" stroke="none"/>',
    "applications-multimedia": '<circle cx="64" cy="64" r="42" stroke-width="4"/><path d="m52 44 30 20-30 20z" fill="url(#acc)" stroke="none"/>',
    "applications-graphics": '<path d="M30 98c0-28 22-50 50-50 12 0 20 8 20 18 0 24-20 38-40 38-10 0-16-4-16-10 0-5 4-9 9-9 4 0 8 3 8 7" stroke-width="4"/><circle cx="88" cy="38" r="10" fill="url(#acc)" stroke="none"/>',
    "image-x-generic": '<rect x="20" y="26" width="88" height="76" rx="8" stroke-width="4"/><circle cx="44" cy="48" r="8"/><path d="m28 92 26-28 16 17 12-12 18 23"/>',
    # Ufficio / sistema
    "applications-office": '<rect x="20" y="42" width="88" height="58" rx="8" stroke-width="4"/><path d="M48 42V30h32v12M20 62h88M64 62v38"/>',
    "applications-utilities": '<path d="M84 30a24 24 0 0 0-30 30L24 90a12 12 0 0 0 17 17l30-30a24 24 0 0 0 30-30l-16 16-17-17z" stroke-width="4"/>',
    "applications-games": '<path d="M34 48h60c14 0 22 12 18 26l-6 20c-3 10-14 12-20 4l-8-10H50l-8 10c-6 8-17 6-20-4l-6-20c-4-14 4-26 18-26Z" stroke-width="4"/><path d="M42 64v16M34 72h16M86 68h.1M96 78h.1" stroke-width="7"/>',
    "applications-system": '<rect x="22" y="22" width="34" height="34" rx="8"/><rect x="72" y="22" width="34" height="34" rx="8"/><rect x="22" y="72" width="34" height="34" rx="8"/><rect x="72" y="72" width="34" height="34" rx="8"/>',
    "preferences-system": '<circle cx="64" cy="64" r="16" stroke-width="4"/><circle cx="64" cy="64" r="32" stroke-width="3" stroke-dasharray="7 9"/><path d="M64 18v12M64 98v12M18 64h12M98 64h12M32 32l9 9M87 87l9 9M96 32l-9 9M41 87l-9 9" stroke-width="5"/>',
    "preferences-desktop": '<rect x="18" y="26" width="92" height="62" rx="8" stroke-width="4"/><path d="M48 104h32M64 88v16M34 74l16-18 12 10 15-20 17 24"/>',
    "preferences-desktop-theme": '<path d="M64 22c-24 0-42 16-42 38 0 20 16 28 32 28h10c8 0 12 6 8 12-4 8 2 14 10 12 22-6 34-26 34-48 0-24-20-42-52-42Z" stroke-width="4"/><circle cx="44" cy="50" r="7" fill="#{soft}" stroke="none"/><circle cx="64" cy="42" r="7" fill="#{accent}" stroke="none"/><circle cx="84" cy="52" r="7" fill="#{soft}" stroke="none"/><circle cx="50" cy="70" r="7" fill="#{accent}" stroke="none"/>',
    "help-browser": '<circle cx="64" cy="64" r="42" stroke-width="4"/><path d="M52 50c0-10 8-16 18-16s18 7 18 16c0 9-7 13-14 18-4 3-6 6-6 12" stroke-width="5"/><circle cx="68" cy="94" r="4" fill="url(#acc)" stroke="none"/>',
    "utilities-system-monitor": '<rect x="18" y="24" width="92" height="80" rx="10" stroke-width="4"/><path d="M30 82h14l10-24 12 36 12-48 10 36h10"/>',
    "edit-find": '<circle cx="54" cy="54" r="30" stroke-width="5"/><path d="m76 76 28 28" stroke-width="7"/>',
    # Stato / sessione
    "system-shutdown": '<path d="M44 34a36 36 0 1 0 40 0" stroke-width="5"/><rect x="61" y="16" width="6" height="46" rx="3" fill="url(#acc)" stroke="none"/>',
    "system-lock-screen": '<rect x="28" y="58" width="72" height="50" rx="10" stroke-width="4"/><path d="M44 58V42a20 20 0 0 1 40 0v16M64 76v14" stroke-width="5"/>',
    "system-log-out": '<path d="M76 24H34a8 8 0 0 0-8 8v64a8 8 0 0 0 8 8h42M82 44l20 20-20 20M102 64H54" stroke-width="5"/>',
    "system-reboot": '<path d="M32 64a32 32 0 1 0 10-23" stroke-width="5"/><path d="M28 22v24h24" stroke-width="5"/>',
    "network-wireless": '<path d="M22 48c24-20 60-20 84 0M36 64c16-12 40-12 56 0M50 80c8-6 20-6 28 0" stroke-width="5"/><circle cx="64" cy="96" r="5" fill="url(#acc)" stroke="none"/>',
    "network-wired": '<rect x="24" y="70" width="28" height="22" rx="4"/><rect x="76" y="70" width="28" height="22" rx="4"/><path d="M52 81h24M38 70V38h52v32M58 26h12v24"/>',
    "network-disconnected": '<path d="M22 48c24-20 60-20 84 0M36 64c16-12 40-12 56 0M50 80c8-6 20-6 28 0" stroke-width="5"/><path d="m88 88 24 24M112 88l-24 24" stroke-width="5"/>',
    "battery-full": '<rect x="18" y="40" width="84" height="48" rx="8" stroke-width="4"/><path d="M108 54v20" stroke-width="8"/><rect x="28" y="50" width="64" height="28" rx="3" fill="url(#acc)" stroke="none"/>',
    "battery-good": '<rect x="18" y="40" width="84" height="48" rx="8" stroke-width="4"/><path d="M108 54v20" stroke-width="8"/><rect x="28" y="50" width="46" height="28" rx="3" fill="url(#acc)" stroke="none"/>',
    "battery-low": '<rect x="18" y="40" width="84" height="48" rx="8" stroke-width="4"/><path d="M108 54v20" stroke-width="8"/><rect x="28" y="50" width="20" height="28" rx="3" fill="url(#acc)" stroke="none"/>',
    "battery-empty": '<rect x="18" y="40" width="84" height="48" rx="8" stroke-width="4"/><path d="M108 54v20" stroke-width="8"/>',
    "system-software-update": '<path d="M32 58a32 32 0 0 1 54-18l10 10M106 30v20H86M96 70a32 32 0 0 1-54 18l-10-10M22 98V78h20" stroke-width="5"/>',
}


def build_theme(conf: Path, output: Path) -> Path:
    colors = parse_theme(conf)
    output.mkdir(parents=True, exist_ok=True)
    theme_id = colors.get("THEME_ID", conf.parent.name)
    theme_name = colors.get("THEME_NAME", theme_id)
    theme_dir = output / theme_id
    if theme_dir.exists():
        shutil.rmtree(theme_dir)
    for context in CONTEXTS:
        (theme_dir / "scalable" / context).mkdir(parents=True, exist_ok=True)

    for name, body in ICONS.items():
        # Sostituisce i token colore nei glyph che li usano.
        body = body.replace("{soft}", colors.get("ACCENT_SOFT", "60a5fa"))
        body = body.replace("{accent}", colors.get("ACCENT", "3b82f6"))
        content = svg(colors, body)
        # Le icone sono disponibili in ogni contesto per compatibilità con
        # applicazioni che cercano nomi in contesti diversi.
        for context in CONTEXTS:
            (theme_dir / "scalable" / context / f"{name}.svg").write_text(
                content, encoding="utf-8"
            )

    index = f"""[Icon Theme]
Name=Labwc Q4OS {theme_name}
Comment=Icone SVG coordinate al tema {theme_name} di labwc-q4os
Inherits=Adwaita,hicolor
Example=folder
Directories={','.join(f'scalable/{c}' for c in CONTEXTS)}

"""
    for context in CONTEXTS:
        index += f"[scalable/{context}]\n"
        index += "Size=128\nType=Scalable\nMinSize=16\nMaxSize=512\n"
        index += f"Context={CONTEXT_NAMES[context]}\n\n"
    (theme_dir / "index.theme").write_text(index, encoding="utf-8")
    (theme_dir / ".labwc-q4os-theme").write_text(theme_id + "\n", encoding="utf-8")
    return theme_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera icone SVG per labwc-q4os")
    parser.add_argument("--all", action="store_true", help="genera tutti i temi")
    parser.add_argument("--themes-dir", type=Path, help="cartella dei temi")
    parser.add_argument("--theme-conf", type=Path, help="theme.conf singolo")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    if args.all:
        if not args.themes_dir or not args.themes_dir.is_dir():
            parser.error("--all richiede --themes-dir")
        confs = sorted(args.themes_dir.glob("*/theme.conf"))
        if not confs:
            parser.error(f"nessun tema in {args.themes_dir}")
        for conf in confs:
            print(build_theme(conf, args.output))
        return 0

    if not args.theme_conf or not args.theme_conf.is_file():
        parser.error("serve --theme-conf oppure --all --themes-dir")
    print(build_theme(args.theme_conf, args.output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
