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
import json
import os
import re
import shlex
import shutil
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from xml.sax.saxutils import escape


def menu_sort_key(label: str) -> str:
    """Ordine alfabetico stabile, senza distinguere maiuscole o accenti."""
    normalized = unicodedata.normalize("NFKD", label.casefold())
    return "".join(char for char in normalized if not unicodedata.combining(char))

HOME = Path.home()
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))


def shell_mode() -> str:
    try:
        value = (CONFIG_HOME / "labwc/shell").read_text(encoding="utf-8").strip()
    except OSError:
        return "waybar"
    return value if value in ("waybar", "noctalia") else "waybar"
LABWC_DIR = CONFIG_HOME / "labwc"
MENU_FILE = LABWC_DIR / "menu.xml"
FAVORITES_FILE = LABWC_DIR / "favorites.tsv"
PLACEMENTS_FILE = LABWC_DIR / "placements.tsv"
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

# App create dall'utente: stanno in $XDG_DATA_HOME/applications ma non sono
# voci del progetto (labwc-*.desktop) ne' scorciatoie *-cage generate da
# install.sh. Finiscono in TOOL reverseloop, raggruppate per categoria.
USER_APPS_DIR = Path(
    os.environ.get("XDG_DATA_HOME", HOME / ".local/share")
) / "applications"
PROJECT_DESKTOP_PREFIXES = ("labwc-",)
PROJECT_DESKTOP_SUFFIXES = ("-cage",)

# Voci .desktop del progetto che duplicano una voce gia' presente in
# TOOL reverseloop: non vanno elencate anche nelle categorie.
PROJECT_TOOL_DUPLICATES = {
    "labwc-help",
    "labwc-menu-editor",
    "labwc-theme-switcher",
    "labwc-preferences",
    "labwc-screen-scaler",
    "labwc-app-manager",
    "labwc-update-gui",
    "labwc-zram",
    "labwc-doctor",
    "labwc-sysinfo",
}

# Sottocategorie per il menu Impostazioni: evita un elenco lunghissimo
# (labwc non ha lo scroll nei menu).
SETTINGS_GROUPS = [
    ("Aspetto e desktop", (
        "tema", "theme", "icon", "cursore", "cursor", "sfondo", "background",
        "font", "caratter", "aspetto", "appearance", "colore", "color", "look",
        "decoraz", "desktop", "widget", "pannello", "panel", "notific",
    )),
    ("Schermo e hardware", (
        "schermo", "screen", "display", "monitor", "scal", "dpi", "tastiera",
        "keyboard", "mouse", "touch", "touchpad", "trackpad", "stampante",
        "printer", "audio", "suono", "sound", "batteria", "battery",
        "alimentaz", "power", "rete", "network", "wifi", "bluetooth",
        "scheda", "driver", "hardware",
    )),
    ("Sistema e sessione", (
        "sistema", "system", "sessione", "session", "login", "utente", "user",
        "account", "password", "aggiorn", "update", "pacchett", "package",
        "software", "firewall", "sicurezza", "security", "data", "date",
        "ora", "time", "lingua", "language", "locale", "regione", "region",
        "serviz", "service", "avvio", "startup", "backup",
    )),
]


def settings_subgroup(name: str, desktop_id: str) -> str:
    text = f"{name} {desktop_id}".casefold()
    for label, keys in SETTINGS_GROUPS:
        if any(key in text for key in keys):
            return label
    return "Altre impostazioni"

# Voci di TDE/Trinity che aprirebbero impostazioni estranee a labwc.
EXCLUDED_DESKTOP_IDS = {
    "kcontrol",
    "systemsettings",
    "trinity-control-center",
    "tde-systemsettings",
    "desktop-settings",
    "q4os-control-center",
    "kcm_desktop",
}
EXCLUDED_NAMES = {
    "preferenze della scrivania",
    "desktop preferences",
    "configure desktop",
    "system settings",
    "preferenze di sistema",
    "trinity control center",
    "centro di controllo",
    "control center",
}
EXCLUDED_CATEGORIES = {"TDE", "Trinity"}
EXCLUDED_COMMANDS = {
    "kcontrol",
    "tdecmshell",
    "systemsettings",
    "kcmshell5",
    "kcmshell6",
    "trinity-control-center",
}

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
    is_user: bool = False
    fingerprint: str = ""

    @property
    def sort_key(self) -> str:
        return menu_sort_key(self.name)


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


def command_fingerprint(command: str) -> str:
    """Firma stabile del programma eseguito.

    Ignora argomenti, variabili d'ambiente e percorso assoluto: due voci che
    lanciano lo stesso binario (es. /usr/bin/firefox e firefox-esr) risultano
    duplicate. Per Flatpak/Snap usa l'ID dell'applicazione.
    """
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    while parts and os.path.basename(parts[0]) == "env":
        parts.pop(0)
        while parts and "=" in parts[0] and not parts[0].startswith("/"):
            parts.pop(0)
    if not parts:
        return ""
    base = os.path.basename(parts[0])
    if base in ("flatpak", "snap"):
        for token in parts[1:]:
            if not token.startswith("-") and token not in ("run", "override"):
                return f"{base}:{token}"
        return base
    return base


def is_project_desktop(desktop_id: str) -> bool:
    """True per le voci .desktop installate dal progetto."""
    return desktop_id.startswith(PROJECT_DESKTOP_PREFIXES) or desktop_id.endswith(
        PROJECT_DESKTOP_SUFFIXES
    )


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


def load_apps(placements: dict[str, str] | None = None) -> list[App]:
    apps: list[App] = []
    seen_ids: set[str] = set()
    seen_fingerprints: dict[str, list[str]] = {}
    system_names: set[str] = set()

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
            if any(key.upper().startswith(("X-TDE", "X-TRINITY")) for key in data):
                continue
            if "/opt/trinity/" in exec_line or "/opt/trinity/" in data.get("TryExec", ""):
                continue
            only_show_in = {item.strip() for item in data.get("OnlyShowIn", "").split(";") if item.strip()}
            not_show_in = {item.strip() for item in data.get("NotShowIn", "").split(";") if item.strip()}
            # Scarta solo le voci riservate a TDE/Trinity: le app GNOME/KDE
            # funzionano comunque sotto labwc e devono restare nel menu.
            if only_show_in & EXCLUDED_CATEGORIES and "LABWC" not in only_show_in:
                continue
            if "LABWC" in not_show_in:
                continue
            categories = {item.strip() for item in data.get("Categories", "").split(";") if item.strip()}
            if categories & EXCLUDED_CATEGORIES:
                continue
            if (desktop_id in EXCLUDED_DESKTOP_IDS
                    or name.casefold() in EXCLUDED_NAMES
                    or os.path.basename(first_command(exec_line)) in EXCLUDED_COMMANDS):
                continue
            if not executable_exists(exec_line):
                continue
            # Le voci .desktop del progetto gia' elencate a mano in
            # TOOL reverseloop non vanno ripetute nelle categorie.
            if desktop_id in PROJECT_TOOL_DUPLICATES:
                continue

            if path.parent != USER_APPS_DIR:
                system_names.add(menu_sort_key(name))

            if is_true(data.get("Terminal", "")):
                command = f"terminator -x sh -c {shlex.quote(exec_line)}"
            else:
                command = exec_line

            automatic_category = choose_category(data.get("Categories", ""))
            category = automatic_category
            if placements and desktop_id in placements:
                candidate = placements[desktop_id]
                if candidate in CATEGORY_ORDER:
                    category = candidate
            application = App(
                desktop_id=desktop_id,
                name=name,
                comment=localized(data, "Comment"),
                command=command,
                category=category,
                icon=data.get("Icon", ""),
                is_user=(
                    path.parent == USER_APPS_DIR
                    and not is_project_desktop(desktop_id)
                    and not first_command(exec_line).startswith(
                        str(HELPER_DIR) + "/"
                    )
                ),
            )
            # Deduplica: stesso programma eseguito e nome uguale o contenuto
            # nell'altro (es. "Firefox" / "Firefox ESR" che lanciano lo stesso
            # binario). Voci con nomi diversi restano separate. La firma usa
            # l'Exec originale: per le app Terminal=true il comando nel menu e'
            # avvolto in terminator e non identifica il programma.
            fingerprint = command_fingerprint(exec_line) or exec_line
            sort_name = menu_sort_key(name)
            previous_names = seen_fingerprints.setdefault(fingerprint, [])
            if any(
                sort_name == old or sort_name in old or old in sort_name
                for old in previous_names
            ):
                continue
            previous_names.append(sort_name)
            application.fingerprint = fingerprint
            apps.append(application)

    # Un override utente di un'app di sistema (stesso nome) resta nel menu
    # principale come le altre app: non e' una "app creata dall'utente".
    for app in apps:
        if app.is_user and menu_sort_key(app.name) in system_names:
            app.is_user = False

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


def read_placements() -> dict[str, str]:
    placements: dict[str, str] = {}
    if not PLACEMENTS_FILE.exists():
        return placements
    try:
        lines = PLACEMENTS_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return placements
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) >= 2 and fields[1] in CATEGORY_ORDER:
            placements[fields[0]] = fields[1]
    return placements


def write_placements(placements: dict[str, str]) -> None:
    LABWC_DIR.mkdir(parents=True, exist_ok=True)
    lines = ["# id\tcategoria -- categorie personalizzate del menu"]
    for desktop_id, category in sorted(placements.items()):
        lines.append(f"{desktop_id}\t{category}")
    tmp = PLACEMENTS_FILE.with_suffix(".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(tmp, PLACEMENTS_FILE)


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


def settings_body(apps: list["App"]) -> str:
    """Raggruppa le app di Impostazioni in sottomenu tematici."""
    groups: dict[str, list[App]] = {}
    for app in apps:
        groups.setdefault(settings_subgroup(app.name, app.desktop_id), []).append(app)
    body = ""
    for label in sorted(groups, key=menu_sort_key):
        rows = sorted(groups[label], key=lambda app: menu_sort_key(app.name))
        inner = "".join(item(app.name, app.command) for app in rows)
        menu_id = "settings-" + re.sub(
            r"[^a-z0-9]+", "-", label.casefold()
        ).strip("-")
        body += submenu(menu_id, label, inner)
    return body


# Voci fisse del menu radice: se un'app del sistema lancia lo stesso programma
# non va ripetuta in una categoria.
PINNED_ROOT_COMMANDS = ("terminator", "pcmanfm", "fuzzel")


def build_menu(apps: list[App], favorites: list[tuple[str, str, str]]) -> str:
    favorites = sorted(favorites, key=lambda row: menu_sort_key(row[1]))
    favorite_ids = {fav[0] for fav in favorites}
    favorite_names = {menu_sort_key(label) for _id, label, _cmd in favorites}
    favorite_keys = {
        (menu_sort_key(label), command_fingerprint(command) or command)
        for _id, label, command in favorites
    }
    pinned = {command_fingerprint(command) for command in PINNED_ROOT_COMMANDS}

    groups: dict[str, list[App]] = {}
    user_groups: dict[str, list[App]] = {}
    for app in apps:
        fingerprint = app.fingerprint or command_fingerprint(app.command) or app.command
        # Una voce per app: le preferite compaiono solo nel loro sottomenu e le
        # voci fisse (Terminale, File manager, launcher) non si ripetono.
        if (
            app.desktop_id in favorite_ids
            or app.sort_key in favorite_names
            or (app.sort_key, fingerprint) in favorite_keys
        ):
            continue
        if not app.is_user and fingerprint in pinned:
            continue
        target = user_groups if app.is_user else groups
        target.setdefault(app.category, []).append(app)

    parts: list[str] = []
    parts.append('<?xml version="1.0" encoding="UTF-8"?>\n')
    parts.append("<!-- Generato da render-menu.py - non modificare a mano. -->\n")
    parts.append("<!-- Per personalizzare: tasto destro > TOOL reverseloop > App nel menu. -->\n")
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
    parts.append(item("Terminale", "terminator"))
    parts.append(item("File manager", "pcmanfm"))
    parts.append(
        f'    <menu id="minimized-menu" label="RIDOTTO AD ICONA" '
        f'execute="{x(helper("labwc-minimized") + " --pipe")}" />\n'
    )
    if shell_mode() == "noctalia":
        parts.append(item("Cerca applicazioni (Noctalia)", "noctalia msg panel-toggle launcher"))
    else:
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

    category_groups = [
        (category, groups.get(category, []))
        for category in CATEGORY_ORDER
        if groups.get(category)
    ]
    category_groups.sort(key=lambda row: menu_sort_key(row[0]))
    for category, cat_apps in category_groups:
        if category == "Impostazioni" and len(cat_apps) > 3:
            body = settings_body(cat_apps)
        else:
            body = "".join(
                item(app.name, app.command)
                for app in sorted(cat_apps, key=lambda app: menu_sort_key(app.name))
            )
        menu_id = "cat-" + re.sub(r"[^a-z0-9]+", "-", category.casefold()).strip("-")
        parts.append(submenu(menu_id, category, body))

    parts.append("    <separator />\n")

    def sorted_body(entries: list[tuple[str, str]]) -> str:
        return "".join(
            body for _label, body in sorted(
                entries, key=lambda row: menu_sort_key(row[0])
            )
        )

    app_menu_entries: list[tuple[str, str]] = [
        ("Gestisci app e preferite", item("Gestisci app e preferite", helper("labwc-app-manager"))),
        ("Editor rapido del menu", item("Editor rapido del menu", helper("labwc-menu-editor"))),
        ("Ricarica menu e desktop", item("Ricarica menu e desktop", helper("labwc-reload"))),
    ]

    session_entries: list[tuple[str, str]] = [
        ("Blocca schermo", item("Blocca schermo", "swaylock -f")),
        ("Menu sessione (blocca, esci, riavvia, spegni)", item("Menu sessione (blocca, esci, riavvia, spegni)", helper("labwc-power-menu"))),
        ("Riconfigura labwc", item("Riconfigura labwc", "labwc --reconfigure")),
    ]

    screen_entries: list[tuple[str, str]] = [
        ("Scala dimensioni dello schermo", item("Scala dimensioni dello schermo", helper("labwc-screen-scaler"))),
        ("Cattura schermo (area)", item("Cattura schermo (area)", helper("labwc-screenshot", "region"))),
        ("Cattura schermo (intero)", item("Cattura schermo (intero)", helper("labwc-screenshot", "full"))),
    ]

    system_entries: list[tuple[str, str]] = [
        ("Informazioni di sistema", item("Informazioni di sistema", f"terminator -x {helper('labwc-sysinfo')}")),
        ("Diagnostica e ripara desktop", item("Diagnostica e ripara desktop", f"terminator -x {helper('labwc-doctor')} --fix")),
        ("Controlli aggiornamenti script labwc-q4os", item("Controlli aggiornamenti script labwc-q4os", helper("labwc-update-gui"))),
        ("ZRAM — memoria compressa", item("ZRAM — memoria compressa", helper("labwc-zram"))),
        ("Bluetooth: accendi o spegni", item("Bluetooth: accendi o spegni", helper("labwc-bluetooth"))),
    ]

    theme_entries: list[tuple[str, str]] = [
        (label, item(label, helper("labwc-theme-switcher", theme_id)))
        for theme_id, label in THEMES
    ]
    theme_entries.append(
        ("Genera di nuovo gli sfondi", item("Genera di nuovo gli sfondi", helper("labwc-generate-wallpapers")))
    )

    desktops_body = "".join(
        item(f"Desktop {n}", helper("labwc-desktop", str(n))) for n in range(1, 5)
    )

    # TOOL corto: le voci frequenti in chiaro, il resto in sottomenu tematici
    # (labwc non ha lo scroll nei menu).
    tool_entries: list[tuple[str, str]] = [
        ("AVVIA CAGE", item("AVVIA CAGE", f"{helper('labwc-cage')} --ask -- terminator --fullscreen -e {helper('labwc-cage-help')}")),
        ("Preferenze della scrivania Labwc", item("Preferenze della scrivania Labwc", helper("labwc-preferences"))),
        ("Aiuto, scorciatoie e sistema", item("Aiuto, scorciatoie e sistema", helper("labwc-help"))),
        ("App e menu", submenu("apps-tools-menu", "App e menu", sorted_body(app_menu_entries))),
        ("Cambia tema", submenu("theme-menu", "Cambia tema", sorted_body(theme_entries))),
        ("Desktop 1–4", submenu("desktop-switcher-menu", "Desktop 1–4", desktops_body)),
        ("Schermo e monitor", submenu("screen-menu", "Schermo e monitor", sorted_body(screen_entries))),
        ("Sessione", submenu("session-tools-menu", "Sessione", sorted_body(session_entries))),
        ("Sistema e diagnostica", submenu("system-menu", "Sistema e diagnostica", sorted_body(system_entries))),
    ]

    # App create dall'utente: tutte dentro TOOL reverseloop, raggruppate con
    # le categorie gia' esistenti (nessuna voce ripetuta nel menu principale).
    for category in sorted(user_groups, key=menu_sort_key):
        rows = sorted(
            user_groups[category], key=lambda app: menu_sort_key(app.name)
        )
        slug = re.sub(r"[^a-z0-9]+", "-", category.casefold()).strip("-")
        tool_entries.append(
            (
                category,
                submenu(
                    f"user-cat-{slug}",
                    category,
                    "".join(item(app.name, app.command) for app in rows),
                ),
            )
        )

    tool_entries.sort(key=lambda row: menu_sort_key(row[0]))
    desktop_body = "".join(body for _label, body in tool_entries)
    parts.append(submenu("desktop-menu", "TOOL reverseloop", desktop_body))

    parts.append("  </menu>\n\n")
    parts.append("</openbox_menu>\n")
    return "".join(parts)


def render_menu() -> None:
    placements = read_placements()
    apps = load_apps(placements)
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


def remove_favorite_id(desktop_id: str) -> int:
    desktop_id = desktop_id.removesuffix(".desktop")
    favorites = read_favorites()
    kept = [fav for fav in favorites if fav[0] != desktop_id]
    if len(kept) == len(favorites):
        print(f"Preferita non trovata: {desktop_id}", file=sys.stderr)
        return 1
    write_favorites(kept)
    render_menu()
    print(f"Rimossa: {desktop_id}")
    return 0


def set_category(desktop_id: str, category: str) -> int:
    desktop_id = desktop_id.removesuffix(".desktop")
    if category not in CATEGORY_ORDER:
        print(f"Categoria non valida: {category}", file=sys.stderr)
        return 1
    if not any(app.desktop_id == desktop_id for app in load_apps()):
        print(f"Applicazione non trovata: {desktop_id}", file=sys.stderr)
        return 1
    placements = read_placements()
    placements[desktop_id] = category
    write_placements(placements)
    render_menu()
    print(f"Categoria impostata: {desktop_id} -> {category}")
    return 0


def clear_category(desktop_id: str) -> int:
    desktop_id = desktop_id.removesuffix(".desktop")
    placements = read_placements()
    if desktop_id not in placements:
        print(f"Nessuna categoria personalizzata per: {desktop_id}")
        return 0
    del placements[desktop_id]
    write_placements(placements)
    render_menu()
    print(f"Categoria automatica ripristinata: {desktop_id}")
    return 0


def json_state() -> None:
    placements = read_placements()
    favorites = read_favorites()
    favorite_ids = {fav[0] for fav in favorites}
    apps = load_apps(placements)
    payload = {
        "categories": CATEGORY_ORDER,
        "favorites": [
            {"id": desktop_id, "name": label, "command": command}
            for desktop_id, label, command in favorites
        ],
        "apps": [
            {
                "id": app.desktop_id,
                "name": app.name,
                "comment": app.comment,
                "category": app.category,
                "command": app.command,
                "favorite": app.desktop_id in favorite_ids,
                "placement": placements.get(app.desktop_id, ""),
                "user": app.is_user,
            }
            for app in apps
        ],
    }
    print(json.dumps(payload, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description="Menu dinamico per labwc-q4os")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--render", action="store_true")
    group.add_argument("--list-available", action="store_true")
    group.add_argument("--list-favorites", action="store_true")
    group.add_argument("--add", metavar="ID")
    group.add_argument("--remove", metavar="INDICE", type=int)
    group.add_argument("--remove-id", metavar="ID")
    group.add_argument("--set-category", nargs=2, metavar=("ID", "CATEGORIA"))
    group.add_argument("--clear-category", metavar="ID")
    group.add_argument("--json", action="store_true")
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
    if args.remove_id:
        return remove_favorite_id(args.remove_id)
    if args.set_category:
        return set_category(args.set_category[0], args.set_category[1])
    if args.clear_category:
        return clear_category(args.clear_category)
    if args.json:
        json_state()
        return 0
    if args.path:
        print(MENU_FILE)
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
