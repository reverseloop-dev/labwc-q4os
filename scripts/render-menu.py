#!/usr/bin/env python3
"""
render-menu.py - genera e gestisce il menu contestuale di labwc.

Sottocomandi:
    --render                 rigenera ~/.config/labwc/menu.xml
    --list-available         elenca le app installate (TSV: id, nome, commento)
    --list-favorites         elenca le app preferite (TSV: indice, nome, id)
    --add ID                 aggiunge un'app preferita
    --remove INDICE          rimuove un'app preferita (indice 1-based)
    --path                   stampa il percorso del menu generato

Le preferite sono salvate in ~/.config/labwc/favorites.tsv (id, nome, comando):
sopravvivono agli aggiornamenti e alla rigenerazione del menu.
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from xml.sax.saxutils import escape

HOME = Path.home()
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
LABWC_DIR = CONFIG_HOME / "labwc"
MENU_FILE = LABWC_DIR / "menu.xml"
FAVORITES_FILE = LABWC_DIR / "favorites.tsv"
HELPER_DIR = HOME / ".local" / "bin"


def helper(name: str, args: str = "") -> str:
    """Percorso assoluto degli helper: labwc non eredita ~/.local/bin nel PATH."""
    command = shlex.quote(str(HELPER_DIR / name))
    return f"{command} {args}".strip()

CATEGORY_MAP = {
    "AudioVideo": "Multimedia",
    "Development": "Sviluppo",
    "Education": "Istruzione",
    "Game": "Giochi",
    "Graphics": "Grafica",
    "Network": "Internet",
    "Office": "Ufficio",
    "Science": "Scienza",
    "Settings": "Impostazioni",
    "System": "Sistema",
    "Utility": "Accessori",
}

CATEGORY_ORDER = [
    "Internet",
    "Multimedia",
    "Grafica",
    "Ufficio",
    "Sviluppo",
    "Giochi",
    "Istruzione",
    "Scienza",
    "Sistema",
    "Impostazioni",
    "Accessori",
    "Altre applicazioni",
]

THEMES = [
    ("nordic-cobalt", "Blu - Nordic Cobalt"),
    ("muted-crimson", "Rosso tenue - Muted Crimson"),
    ("sage-emerald", "Verde salvia - Sage Emerald"),
]


@dataclass
class App:
    desktop_id: str
    name: str
    comment: str
    command: str
    category: str
    icon: str = ""

    @property
    def sort_key(self) -> str:
        return self.name.casefold()


def desktop_dirs() -> list[Path]:
    dirs: list[Path] = []
    data_home = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
    dirs.append(data_home / "applications")
    data_dirs = os.environ.get(
        "XDG_DATA_DIRS", "/usr/local/share:/usr/share"
    ).split(":")
    for d in data_dirs:
        if d.strip():
            dirs.append(Path(d) / "applications")
    dirs.extend(
        [
            HOME / ".local/share/flatpak/exports/share/applications",
            Path("/var/lib/flatpak/exports/share/applications"),
            Path("/var/lib/snapd/desktop/applications"),
        ]
    )
    # preserva l'ordine, elimina duplicati
    seen: set[str] = set()
    result: list[Path] = []
    for d in dirs:
        key = str(d)
        if key not in seen:
            seen.add(key)
            result.append(d)
    return result


def parse_desktop(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    in_entry = False
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return data
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_entry = line == "[Desktop Entry]"
            continue
        if not in_entry or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        # la prima occorrenza vince (le successive sono traduzioni/overrides)
        if key not in data:
            data[key] = value.strip()
    return data


def localized(data: dict[str, str], key: str) -> str:
    for suffix in ("[it_IT]", "[it]", ""):
        value = data.get(f"{key}{suffix}", "")
        if value:
            return value
    return ""


def is_true(value: str) -> bool:
    return value.strip().lower() in ("1", "true", "yes")


def clean_exec(exec_line: str) -> str:
    """Rimuove i field code di freedesktop e normalizza gli spazi."""
    exec_line = exec_line.strip()
    if not exec_line:
        return ""
    sentinel = "\x00PERCENT\x00"
    exec_line = exec_line.replace("%%", sentinel)
    exec_line = re.sub(r"%[fFuUdDnNickvm]", "", exec_line)
    exec_line = exec_line.replace(sentinel, "%")
    exec_line = re.sub(r"[ \t]{2,}", " ", exec_line).strip()
    return exec_line


def first_command(exec_line: str) -> str:
    try:
        parts = shlex.split(exec_line)
    except ValueError:
        parts = exec_line.split()
    if not parts:
        return ""
    if os.path.basename(parts[0]) == "env":
        for part in parts[1:]:
            if "=" in part and not part.startswith("/"):
                continue
            return part
        return ""
    return parts[0]


def executable_exists(exec_line: str) -> bool:
    token = first_command(exec_line)
    if not token:
        return False
    if token.startswith("/"):
        return os.path.isfile(token) and os.access(token, os.X_OK)
    return shutil.which(token) is not None


def try_exec_ok(data: dict[str, str]) -> bool:
    try_exec = data.get("TryExec", "").strip()
    if not try_exec:
        return True
    if try_exec.startswith("/"):
        return os.path.isfile(try_exec) and os.access(try_exec, os.X_OK)
    return shutil.which(try_exec) is not None


def choose_category(categories: str) -> str:
    for raw in categories.split(";"):
        cat = raw.strip()
        if cat in CATEGORY_MAP:
            return CATEGORY_MAP[cat]
    return "Altre applicazioni"


def load_apps() -> list[App]:
    apps: list[App] = []
    seen_ids: set[str] = set()
    seen_signatures: set[tuple[str, str]] = set()

    for directory in desktop_dirs():
        if not directory.is_dir():
            continue
        try:
            entries = sorted(directory.glob("*.desktop"))
        except OSError:
            continue
        for path in entries:
            desktop_id = path.stem
            if desktop_id in seen_ids:
                continue
            seen_ids.add(desktop_id)

            data = parse_desktop(path)
            if not data:
                continue
            if data.get("Type", "Application") != "Application":
                continue
            if is_true(data.get("NoDisplay", "")) or is_true(data.get("Hidden", "")):
                continue
            if not try_exec_ok(data):
                continue

            name = localized(data, "Name")
            exec_line = clean_exec(data.get("Exec", ""))
            if not name or not exec_line:
                continue
            if not executable_exists(exec_line):
                continue

            if is_true(data.get("Terminal", "")):
                command = f"foot -e sh -c {shlex.quote(exec_line)}"
            else:
                command = exec_line

            application = App(
                desktop_id=desktop_id,
                name=name,
                comment=localized(data, "Comment"),
                command=command,
                category=choose_category(data.get("Categories", "")),
                icon=data.get("Icon", ""),
            )
            signature = (application.name.casefold(), application.command)
            if signature in seen_signatures:
                continue
            seen_signatures.add(signature)
            apps.append(application)

    apps.sort(key=lambda a: (a.category, a.sort_key))
    return apps


def read_favorites() -> list[tuple[str, str, str]]:
    favorites: list[tuple[str, str, str]] = []
    if not FAVORITES_FILE.exists():
        return favorites
    try:
        lines = FAVORITES_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return favorites
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 3:
            continue
        desktop_id, label, command = fields[0], fields[1], fields[2]
        if not label or not command:
            continue
        favorites.append((desktop_id, label, command))
    return favorites


def write_favorites(favorites: list[tuple[str, str, str]]) -> None:
    LABWC_DIR.mkdir(parents=True, exist_ok=True)
    lines = ["# id\tnome\tcomando -- gestito da labwc-menu-editor"]
    for desktop_id, label, command in favorites:
        safe_id = desktop_id.replace("\t", " ")
        safe_label = label.replace("\t", " ").replace("\n", " ")
        safe_command = command.replace("\t", " ").replace("\n", " ")
        lines.append(f"{safe_id}\t{safe_label}\t{safe_command}")
    tmp = FAVORITES_FILE.with_suffix(".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(tmp, FAVORITES_FILE)


def x(value: str) -> str:
    return escape(str(value), {'"': "&quot;", "'": "&apos;"})


def item(label: str, command: str) -> str:
    return (
        f'    <item label="{x(label)}">\n'
        f'      <action name="Execute" command="{x(command)}" />\n'
        f"    </item>\n"
    )


def submenu(menu_id: str, label: str, body: str) -> str:
    return (
        f'  <menu id="{x(menu_id)}" label="{x(label)}">\n'
        f"{body}"
        f"  </menu>\n"
    )


def build_menu(apps: list[App], favorites: list[tuple[str, str, str]]) -> str:
    groups: dict[str, list[App]] = {}
    for app in apps:
        groups.setdefault(app.category, []).append(app)

    parts: list[str] = []
    parts.append('<?xml version="1.0" encoding="UTF-8"?>\n')
    parts.append("<!-- Generato da render-menu.py - non modificare a mano. -->\n")
    parts.append("<!-- Per personalizzare: tasto destro > Labwc & Desktop > App nel menu. -->\n")
    parts.append("<openbox_menu>\n\n")

    # Menu della finestra (tasto destro sul titolo)
    parts.append('  <menu id="client-menu">\n')
    parts.append(
        '    <item label="Riduci a icona"><action name="Iconify" /></item>\n'
        '    <item label="Massimizza / Ripristina"><action name="ToggleMaximize" /></item>\n'
        '    <item label="Schermo intero"><action name="ToggleFullscreen" /></item>\n'
        '    <item label="Sempre in primo piano"><action name="ToggleAlwaysOnTop" /></item>\n'
        '    <separator />\n'
        '    <menu id="client-send-to-desktop-menu" label="Sposta nel desktop">\n'
        '      <item label="Desktop 1"><action name="SendToDesktop" to="1" follow="yes" /></item>\n'
        '      <item label="Desktop 2"><action name="SendToDesktop" to="2" follow="yes" /></item>\n'
        '      <item label="Desktop 3"><action name="SendToDesktop" to="3" follow="yes" /></item>\n'
        '      <item label="Desktop 4"><action name="SendToDesktop" to="4" follow="yes" /></item>\n'
        '    </menu>\n'
        '    <item label="Chiudi finestra"><action name="Close" /></item>\n'
        "  </menu>\n\n"
    )

    # Menu radice
    parts.append('  <menu id="root-menu" label="Labwc">\n')
    parts.append('    <separator label="reverseloop-dev" />\n')
    parts.append(item("Terminale", "foot"))
    parts.append(item("File manager", "pcmanfm"))
    parts.append(item("Cerca applicazioni (Fuzzel)", "fuzzel"))
    parts.append("    <separator />\n")

    favorites_body = ""
    if favorites:
        for _, label, command in favorites:
            favorites_body += item(label, command)
    else:
        favorites_body += item(
            "Nessuna preferita: aggiungine una...", helper("labwc-menu-editor", "add")
        )
    parts.append(submenu("favorites-menu", "★ App preferite", favorites_body))
    parts.append("    <separator />\n")

    for category in CATEGORY_ORDER:
        cat_apps = groups.get(category, [])
        if not cat_apps:
            continue
        body = "".join(item(app.name, app.command) for app in cat_apps)
        menu_id = "cat-" + re.sub(r"[^a-z0-9]+", "-", category.casefold()).strip("-")
        parts.append(submenu(menu_id, category, body))

    parts.append("    <separator />\n")

    desktop_body = ""
    desktop_body += item("Aggiungi / rimuovi app nel menu", helper("labwc-menu-editor"))
    desktop_body += item("Ricarica menu e desktop", helper("labwc-reload"))
    desktop_body += item("Aiuto e scorciatoie", helper("labwc-help"))
    desktop_body += "    <separator />\n"
    desktop_body += item("Cattura schermo (area)", helper("labwc-screenshot", "region"))
    desktop_body += item("Cattura schermo (intero)", helper("labwc-screenshot", "full"))
    desktop_body += item("ZRAM — memoria compressa", helper("labwc-zram"))
    desktop_body += item("Diagnostica e ripara desktop", f"foot -H -e {helper('labwc-doctor')} --fix")
    desktop_body += item("Blocca schermo", "swaylock -f")
    desktop_body += item("Menu sessione (esci, riavvia, spegni)", "wlogout")
    desktop_body += "    <separator />\n"
    desktop_body += item("Riconfigura labwc", "labwc --reconfigure")

    theme_body = ""
    for theme_id, label in THEMES:
        theme_body += item(label, helper("labwc-theme-switcher", theme_id))
    theme_body += "    <separator />\n"
    theme_body += item("Genera di nuovo gli sfondi", helper("labwc-generate-wallpapers"))
    desktop_body += submenu("theme-menu", "Cambia tema", theme_body)

    parts.append(submenu("desktop-menu", "Labwc & Desktop", desktop_body))

    parts.append("  </menu>\n\n")
    parts.append("</openbox_menu>\n")
    return "".join(parts)


def render_menu() -> None:
    apps = load_apps()
    favorites = read_favorites()
    LABWC_DIR.mkdir(parents=True, exist_ok=True)
    content = build_menu(apps, favorites)
    tmp = MENU_FILE.with_suffix(".xml.tmp")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, MENU_FILE)
    print(f"Menu generato: {MENU_FILE} ({len(apps)} applicazioni, {len(favorites)} preferite)")


def list_available() -> None:
    favorites_ids = {fav[0] for fav in read_favorites()}
    for app in load_apps():
        if app.desktop_id in favorites_ids:
            continue
        print(f"{app.desktop_id}\t{app.name}\t{app.comment}")


def list_favorites() -> None:
    for index, (desktop_id, label, _command) in enumerate(read_favorites(), start=1):
        print(f"{index}\t{label}\t{desktop_id}")


def add_favorite(desktop_id: str) -> int:
    desktop_id = desktop_id.removesuffix(".desktop")
    favorites = read_favorites()
    if any(fav[0] == desktop_id for fav in favorites):
        print("Applicazione gia' presente nelle preferite.")
        return 0
    app = next((a for a in load_apps() if a.desktop_id == desktop_id), None)
    if app is None:
        print(f"Applicazione non trovata: {desktop_id}", file=sys.stderr)
        return 1
    favorites.append((app.desktop_id, app.name, app.command))
    write_favorites(favorites)
    render_menu()
    print(f"Aggiunta: {app.name}")
    return 0


def remove_favorite(index: int) -> int:
    favorites = read_favorites()
    if index < 1 or index > len(favorites):
        print("Indice non valido.", file=sys.stderr)
        return 1
    removed = favorites.pop(index - 1)
    write_favorites(favorites)
    render_menu()
    print(f"Rimossa: {removed[1]}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Menu dinamico per labwc-q4os")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--render", action="store_true")
    group.add_argument("--list-available", action="store_true")
    group.add_argument("--list-favorites", action="store_true")
    group.add_argument("--add", metavar="ID")
    group.add_argument("--remove", metavar="INDICE", type=int)
    group.add_argument("--path", action="store_true")
    args = parser.parse_args()

    if args.render:
        render_menu()
        return 0
    if args.list_available:
        list_available()
        return 0
    if args.list_favorites:
        list_favorites()
        return 0
    if args.add:
        return add_favorite(args.add)
    if args.remove is not None:
        return remove_favorite(args.remove)
    if args.path:
        print(MENU_FILE)
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
