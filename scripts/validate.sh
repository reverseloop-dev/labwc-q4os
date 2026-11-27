#!/usr/bin/env bash
# =============================================================================
#  validate.sh — controlli statici e smoke test del repository labwc-q4os
#  Non installa nulla e non tocca la HOME reale: usa una HOME temporanea.
# =============================================================================
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

fail=0
check() { printf '[ check ] %s\n' "$*"; }
pass()  { printf '[   ok  ] %s\n' "$*"; }
bad()   { printf '[  FAIL ] %s\n' "$*" >&2; fail=1; }

# --- 1. sintassi Bash ---------------------------------------------------------
check "sintassi Bash"
while IFS= read -r -d '' file; do
    if head -n1 "$file" | grep -qE 'bash|sh'; then
        if bash -n "$file"; then
            pass "$file"
        else
            bad "bash -n $file"
        fi
    fi
done < <(find . -path ./.git -prune -o -type f \( -name '*.sh' -o -path './scripts/*' -o -name 'bootstrap.sh' \) -print0)

# --- 2. sintassi Python ------------------------------------------------------
check "sintassi Python"
PYCACHE_DIR="$(mktemp -d)"
if PYTHONPYCACHEPREFIX="$PYCACHE_DIR" python3 -m py_compile scripts/generate-wallpapers.py scripts/generate-login-logo.py scripts/render-menu.py scripts/labwc-zram scripts/labwc-bluetooth scripts/labwc-cage-hud scripts/labwc-app-manager scripts/labwc-update-gui scripts/labwc-login-theme scripts/labwc-fuzzel-apps scripts/labwc-preferences scripts/labwc-install-wizard scripts/freetube-close-overlay scripts/labwc-battery-indicator scripts/generate-icons.py; then
    pass "Python: sfondi, logo login, menu, zram, bluetooth, HUD batteria, app manager, update GUI, login, fuzzel, preferences, overlay FreeTube, batteria, icone"
else
    bad "py_compile"
fi
rm -rf "$PYCACHE_DIR"
if python3 scripts/labwc-zram --status >/dev/null 2>&1; then
    pass "labwc-zram --status"
else
    bad "labwc-zram --status"
fi
if bash scripts/labwc-power-menu --help >/dev/null 2>&1; then
    pass "labwc-power-menu --help"
else
    bad "labwc-power-menu --help"
fi
if LABWC_POWER_DRY_RUN=1 bash scripts/labwc-power-menu --action reboot | grep -q 'DRY-RUN'; then
    pass "labwc-power-menu --action (dry-run)"
else
    bad "labwc-power-menu --action (dry-run)"
fi
if python3 scripts/freetube-close-overlay --self-test | grep -q 'SELFTEST_OK'; then
    pass "freetube-close-overlay --self-test"
else
    bad "freetube-close-overlay --self-test"
fi
if python3 scripts/freetube-close-overlay --version | grep -q '^freetube-close-overlay 2$'; then
    pass "freetube-close-overlay --version"
else
    bad "freetube-close-overlay --version"
fi
CAGE_JS="$(mktemp)"
if python3 scripts/freetube-close-overlay --help >/dev/null 2>&1 &&
    python3 scripts/freetube-close-overlay --print-js >"$CAGE_JS" &&
    grep -q 'labwcCloseX' "$CAGE_JS" &&
    grep -q 'showPopover' "$CAGE_JS" &&
    grep -q 'MutationObserver' "$CAGE_JS"; then
    pass "freetube-close-overlay --help/--print-js"
else
    bad "freetube-close-overlay --help/--print-js"
fi
rm -f "$CAGE_JS"
if python3 scripts/labwc-battery-indicator --self-test | grep -q 'SELFTEST_OK' &&
    python3 scripts/labwc-battery-indicator --help 2>&1 | grep -qi 'posizione'; then
    pass "labwc-battery-indicator --self-test/--help"
else
    bad "labwc-battery-indicator --self-test/--help"
fi
# Smoke test del wrapper: FreeTube finto che ignora SIGTERM e overlay che
# chiede la chiusura. Il wrapper deve escalare a SIGKILL e uscire con 0.
CAGE_TMP="$(mktemp -d)"
mkdir -p "$CAGE_TMP/bin" "$CAGE_TMP/home/.config/FreeTube"
cat >"$CAGE_TMP/bin/freetube" <<'STUB'
#!/usr/bin/env bash
printf '9999\n/devtools/browser/mock\n' > "$XDG_CONFIG_HOME/FreeTube/DevToolsActivePort"
trap '' TERM
while :; do sleep 0.1; done
STUB
chmod 0755 "$CAGE_TMP/bin/freetube"
cat >"$CAGE_TMP/overlay" <<'STUB'
import time
time.sleep(0.2)
raise SystemExit(10)
STUB
chmod 0755 "$CAGE_TMP/overlay"
if HOME="$CAGE_TMP/home" XDG_CONFIG_HOME="$CAGE_TMP/home/.config" \
    XDG_STATE_HOME="$CAGE_TMP/home/.local/state" \
    PATH="$CAGE_TMP/bin:$PATH" LABWC_FREETUBE_OVERLAY="$CAGE_TMP/overlay" \
    timeout 20 bash scripts/labwc-freetube-cage; then
    pass "labwc-freetube-cage: chiusura forzata del process tree"
else
    bad "labwc-freetube-cage: chiusura forzata del process tree"
fi
if pgrep -f "$CAGE_TMP/bin/freetube" >/dev/null 2>&1; then
    bad "labwc-freetube-cage: processo FreeTube rimasto attivo"
    pkill -KILL -f "$CAGE_TMP/bin/freetube" 2>/dev/null || true
else
    pass "labwc-freetube-cage: nessun processo residuo"
fi
rm -rf "$CAGE_TMP"
# exit nella console di Cage: labwc-cage-help deve lasciare il marcatore che
# il wrapper di sessione usa per chiudere Cage e le app rimaste.
CAGE_EXIT_TMP="$(mktemp -d)"
if LABWC_CAGE_CLOSE="$CAGE_EXIT_TMP/cage-exit.request" \
    XDG_STATE_HOME="$CAGE_EXIT_TMP/state" SHELL=/bin/true \
    bash scripts/labwc-cage-help </dev/null >/dev/null 2>&1 &&
    [ -s "$CAGE_EXIT_TMP/cage-exit.request" ]; then
    pass "labwc-cage-help: exit scrive cage-exit.request"
else
    bad "labwc-cage-help: marcatore di uscita mancante"
fi
rm -rf "$CAGE_EXIT_TMP"
if [ -s VERSION ]; then pass "VERSION"; else bad "VERSION"; fi
if [ -s CHANGELOG.md ] &&
   grep -q "^## \[$(tr -d '[:space:]' < VERSION)\]" CHANGELOG.md; then
    pass "CHANGELOG con la versione corrente"
else
    bad "CHANGELOG.md manca la sezione della versione in VERSION"
fi
# Integrita' del repository: manifest, ancora in bootstrap e copertura file.
if sha256sum -c --strict --quiet SHA256SUMS >/dev/null 2>&1; then
    pass "SHA256SUMS verificato"
else
    bad "SHA256SUMS non valido (esegui scripts/make-checksums)"
fi
manifest_now="$(sha256sum SHA256SUMS 2>/dev/null | cut -d' ' -f1)"
if grep -q "MANIFEST_SHA256=\"$manifest_now\"" bootstrap.sh; then
    pass "ancora SHA256SUMS allineata in bootstrap.sh"
else
    bad "MANIFEST_SHA256 in bootstrap.sh non corrisponde (esegui scripts/make-checksums)"
fi
tracked="$(git ls-files | grep -vE '^(SHA256SUMS|bootstrap\.sh)$' | LC_ALL=C sort)"
manifest_files="$(cut -d' ' -f3- SHA256SUMS | LC_ALL=C sort)"
if [ "$tracked" = "$manifest_files" ]; then
    pass "SHA256SUMS copre tutti i file tracciati"
else
    bad "SHA256SUMS non copre esattamente i file tracciati"
fi
UPDTMP="$(mktemp -d)"
mkdir -p "$UPDTMP/share"
if HOME="$UPDTMP" LABWC_Q4OS_SHARE="$UPDTMP/share" \
    XDG_CONFIG_HOME="$UPDTMP/.config" XDG_DATA_HOME="$UPDTMP/.local/share" \
    XDG_STATE_HOME="$UPDTMP/.local/state" \
    bash scripts/labwc-update-check --status | jq -e '.repo' >/dev/null; then
    pass "labwc-update-check --status"
else
    bad "labwc-update-check --status"
fi
rm -rf "$UPDTMP"
if python3 scripts/labwc-update-gui --help >/dev/null 2>&1; then
    pass "labwc-update-gui --help"
else
    bad "labwc-update-gui --help"
fi
if bash scripts/labwc-update-run --print | grep -q 'bootstrap.sh | bash'; then
    pass "labwc-update-run esegue il bootstrap nel terminale"
else
    bad "labwc-update-run --print"
fi
if command -v xvfb-run >/dev/null 2>&1; then
    if xvfb-run -a python3 scripts/labwc-update-gui --smoke 2>/dev/null | grep -q GUI_OK; then
        pass "labwc-update-gui --smoke (finestra costruita)"
    else
        bad "labwc-update-gui --smoke"
    fi
fi
if python3 scripts/labwc-login-theme --show >/dev/null 2>&1; then
    pass "labwc-login-theme --show"
else
    bad "labwc-login-theme --show"
fi
if bash scripts/labwc-login-theme-apply nordic-cobalt >/dev/null 2>&1; then
    bad "labwc-login-theme-apply non rifiuta l'utente normale"
else
    pass "labwc-login-theme-apply richiede root"
fi
APPS_TMP="$(mktemp -d)"
created="$(XDG_DATA_HOME="$APPS_TMP" python3 scripts/labwc-fuzzel-apps \
    --add "App Test" --exec /bin/true --icon utilities-terminal 2>/dev/null || true)"
if [ -f "$created" ] && XDG_DATA_HOME="$APPS_TMP" python3 scripts/labwc-fuzzel-apps \
    --remove "$(basename "$created")" >/dev/null 2>&1 && [ ! -e "$created" ]; then
    pass "labwc-fuzzel-apps aggiunge e rimuove l'app utente"
else
    bad "labwc-fuzzel-apps round-trip"
fi
rm -rf "$APPS_TMP"
APPS_TMP="$(mktemp -d)"
spaced="$(XDG_DATA_HOME="$APPS_TMP" python3 scripts/labwc-fuzzel-apps \
    --add "A B" --exec "/tmp/a b/x %U" 2>/dev/null || true)"
if [ -f "$spaced" ] && grep -q '^Exec="/tmp/a b/x" %U$' "$spaced"; then
    pass "labwc-fuzzel-apps quota Exec con spazi e mantiene %U"
else
    bad "labwc-fuzzel-apps quoting Exec"
fi
rm -rf "$APPS_TMP"

# --- shell desktop: flag --shell e marker di sessione -------------------------
check "shell desktop (--shell, marker sessione)"
if bash install.sh --help | grep -q -- '--shell'; then
    pass "install.sh --help include --shell"
else
    bad "install.sh --help senza --shell"
fi
SHELL_ERR="$(mktemp)"
if bash install.sh --shell valore-non-valido </dev/null >/dev/null 2>"$SHELL_ERR"; then
    bad "install.sh --shell accetta valori non validi"
elif grep -q 'non valido' "$SHELL_ERR"; then
    pass "install.sh --shell rifiuta valori non validi"
else
    bad "install.sh --shell: errore inatteso (non e' la validazione)"
fi
rm -f "$SHELL_ERR"
if bash install.sh --help 2>/dev/null | grep -q -- '--lookswitcher' &&
    bash install.sh --help 2>/dev/null | grep -q -- '--no-lookswitcher'; then
    pass "install.sh --help include --lookswitcher/--no-lookswitcher (Trinity)"
else
    bad "install.sh --help senza i flag LookSwitcher"
fi
# session-start headless: HOME isolata e PATH minimo senza waybar/noctalia,
# cosi' non viene avviato alcun componente reale.
SESS_TMP="$(mktemp -d)"
SESS_STUB="$SESS_TMP/bin"
SESS_LOG="$SESS_TMP/home/.local/state/labwc-q4os/session.log"
mkdir -p "$SESS_STUB" "$SESS_TMP/home/.config/labwc" "$(dirname "$SESS_LOG")"
for tool in mkdir date tr pgrep pkill setsid sleep head timeout; do
    tool_path="$(command -v "$tool" 2>/dev/null || true)"
    if [ -n "$tool_path" ]; then ln -s "$tool_path" "$SESS_STUB/$tool"; fi
done
for stub in waybar mako swaybg; do
    printf '#!/bin/sh\necho "%s-started" >> "%s"\n' "$stub" "$SESS_LOG" > "$SESS_STUB/$stub"
    chmod 0755 "$SESS_STUB/$stub"
done
sess_run() {
    : > "$SESS_LOG" 2>/dev/null || true
    HOME="$SESS_TMP/home" XDG_CONFIG_HOME="$SESS_TMP/home/.config" \
        XDG_DATA_HOME="$SESS_TMP/home/.local/share" \
        XDG_STATE_HOME="$SESS_TMP/home/.local/state" \
        PATH="$SESS_STUB" "$BASH" scripts/labwc-session-start
}
if sess_run && grep -q 'sessione pronta' "$SESS_LOG" &&
    grep -q 'waybar-started' "$SESS_LOG" && ! grep -q 'noctalia-started' "$SESS_LOG"; then
    pass "session-start senza marker (default waybar)"
else
    bad "session-start senza marker"
fi
printf 'noctalia\n' > "$SESS_TMP/home/.config/labwc/shell"
if sess_run && grep -q 'comando mancante' "$SESS_LOG" && grep -q 'waybar-started' "$SESS_LOG"; then
    pass "session-start marker noctalia senza comando (fallback waybar)"
else
    bad "session-start marker noctalia senza comando"
fi
printf 'valore-non-valido\n' > "$SESS_TMP/home/.config/labwc/shell"
if sess_run && grep -q 'waybar-started' "$SESS_LOG"; then
    pass "session-start marker non valido (default waybar)"
else
    bad "session-start marker non valido"
fi
printf '#!/bin/sh\necho "noctalia-started" >> "%s"\n' "$SESS_LOG" > "$SESS_STUB/noctalia"
chmod 0755 "$SESS_STUB/noctalia"
printf 'noctalia\n' > "$SESS_TMP/home/.config/labwc/shell"
if sess_run && grep -q 'noctalia-started' "$SESS_LOG" && ! grep -q 'waybar-started' "$SESS_LOG"; then
    pass "session-start marker noctalia (una sola shell)"
else
    bad "session-start marker noctalia"
fi
sleep 1
rm -rf "$SESS_TMP"

# Wrapper di sessione: con configurazione minima deve dichiararsi pronta.
WRAP_TMP="$(mktemp -d)"
mkdir -p "$WRAP_TMP/.config/labwc"
printf '<labwc_config/>\n' > "$WRAP_TMP/.config/labwc/rc.xml"
printf '<openbox_menu/>\n' > "$WRAP_TMP/.config/labwc/menu.xml"
printf '#!/bin/sh\n' > "$WRAP_TMP/.config/labwc/autostart"
chmod 0755 "$WRAP_TMP/.config/labwc/autostart"
if HOME="$WRAP_TMP" XDG_CONFIG_HOME="$WRAP_TMP/.config" \
    XDG_DATA_HOME="$WRAP_TMP/.local/share" \
    XDG_STATE_HOME="$WRAP_TMP/.local/state" \
    bash scripts/labwc-session-launch --check | grep -q 'sessione pronta'; then
    pass "labwc-session-launch --check con configurazione completa"
else
    bad "labwc-session-launch --check"
fi
if grep -q 'labwc -C' scripts/labwc-session-launch; then
    pass "wrapper usa -C (directory configurazione), non -c"
else
    bad "wrapper: labwc deve usare -C per la directory"
fi
rm -rf "$WRAP_TMP"

# Menu coerente con la shell: con marker noctalia usa il launcher Noctalia.
MENU_TMP="$(mktemp -d)"
mkdir -p "$MENU_TMP/.config/labwc"
printf 'noctalia\n' > "$MENU_TMP/.config/labwc/shell"
if HOME="$MENU_TMP" XDG_CONFIG_HOME="$MENU_TMP/.config" \
    XDG_DATA_HOME="$MENU_TMP/.local/share" \
    python3 scripts/render-menu.py --render >/dev/null 2>&1 &&
    grep -q 'noctalia msg panel-toggle launcher' "$MENU_TMP/.config/labwc/menu.xml"; then
    pass "menu con launcher Noctalia quando la shell e' noctalia"
else
    bad "menu shell-aware (Noctalia)"
fi
rm -rf "$MENU_TMP"

# --- 3. JSON -----------------------------------------------------------------
check "JSON (Waybar, wlogout)"
if jq empty configs/waybar/config.jsonc; then pass "waybar/config.jsonc"; else bad "waybar/config.jsonc"; fi
if jq empty configs/wlogout/layout; then pass "wlogout/layout"; else bad "wlogout/layout"; fi

# --- 4. XML ------------------------------------------------------------------
check "XML (labwc rc.xml)"
if xmllint --noout configs/labwc/rc.xml; then pass "labwc/rc.xml"; else bad "labwc/rc.xml"; fi
if grep -q '<decoration>server</decoration>' configs/labwc/rc.xml &&
    grep -q '<layout>icon:iconify,max,close</layout>' configs/labwc/rc.xml; then
    pass "pulsanti finestra: riduci, ingrandisci, chiudi"
else
    bad "pulsanti finestra mancanti in labwc/rc.xml"
fi

# --- 5. permessi eseguibili -------------------------------------------------
check "permessi eseguibili"
for f in install.sh bootstrap.sh scripts/labwc-theme-apply scripts/labwc-theme-switcher \
         scripts/labwc-menu-editor scripts/labwc-reload scripts/labwc-generate-wallpapers \
         scripts/labwc-help scripts/labwc-screenshot scripts/labwc-zram scripts/labwc-bluetooth scripts/labwc-doctor \
         scripts/labwc-app-manager scripts/labwc-install-wizard scripts/labwc-update-check scripts/labwc-update-copy \
         scripts/labwc-update-popup scripts/labwc-update-run scripts/labwc-update-toggle \
         scripts/labwc-update-gui scripts/labwc-preferences \
         scripts/labwc-login-theme scripts/labwc-login-theme-apply scripts/labwc-session-launch \
         scripts/labwc-fuzzel-apps scripts/labwc-minimized scripts/labwc-install-wizard scripts/labwc-cage scripts/labwc-freetube scripts/labwc-freetube-cage scripts/freetube-close-overlay scripts/labwc-cage-help scripts/labwc-return \
         scripts/labwc-desktop scripts/labwc-desktop-state scripts/labwc-desktop-status scripts/labwc-desktop-menu \
         scripts/labwc-power-menu scripts/labwc-sysinfo \
         scripts/labwc-battery-indicator \
         scripts/labwc-touchscreen \
         scripts/labwc-touch-tap \
         scripts/labwc-session-start scripts/validate.sh scripts/generate-wallpapers.py \
         scripts/render-menu.py scripts/generate-icons.py; do
    if [ -x "$f" ]; then pass "$f"; else bad "$f non eseguibile"; fi
done

# --- 6. smoke test in HOME temporanea ---------------------------------------
check "smoke test tema + menu in HOME temporanea"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Isola anche XDG_*: altrimenti i test scrivono nella HOME reale.
export XDG_CONFIG_HOME="$TMP/.config" XDG_DATA_HOME="$TMP/.local/share"
export XDG_STATE_HOME="$TMP/.local/state"
mkdir -p "$TMP/share/themes" "$TMP/share/templates" "$TMP/share/scripts" "$TMP/share/wallpapers"
cp -a configs/themes/. "$TMP/share/themes/"
cp configs/waybar/style.css.in "$TMP/share/templates/waybar-style.css"
cp configs/fuzzel/fuzzel.ini.in "$TMP/share/templates/fuzzel.ini"
cp configs/mako/config.in "$TMP/share/templates/mako-config"
cp configs/wlogout/style.css.in "$TMP/share/templates/wlogout-style.css"
install -m 0755 scripts/generate-icons.py "$TMP/share/scripts/generate-icons.py"

for theme in nordic-cobalt muted-crimson sage-emerald; do
    if HOME="$TMP" LABWC_Q4OS_SHARE="$TMP/share" LABWC_Q4OS_SKIP_LOGIN=1 \
        bash scripts/labwc-theme-apply "$theme" --no-reload --quiet >/dev/null; then
        pass "tema $theme"
    else
        bad "tema $theme"
    fi
    if grep -Rq '@@[A-Z_]*@@' "$TMP/.config/waybar" "$TMP/.config/fuzzel" "$TMP/.config/mako" "$TMP/.config/wlogout"; then
        bad "token non sostituiti nel tema $theme"
    else
        pass "token sostituiti nel tema $theme"
    fi
    if grep -REq 'rgba\(#?[0-9a-fA-F]{6}' "$TMP/.config/waybar/style.css"; then
        bad "colore rgba non valido in waybar/style.css (tema $theme)"
    else
        pass "colori CSS validi nel tema $theme"
    fi
    if [ -f "$TMP/.config/labwc/themerc-override" ]; then
        pass "themerc-override generato nel tema $theme"
    else
        bad "themerc-override mancante nel tema $theme"
    fi
    if [ -r "$TMP/.local/share/icons/labwc-q4os/index.theme" ]; then
        pass "icone del tema $theme"
    else
        bad "icone del tema $theme mancanti"
    fi
done

# Idempotenza blocco touch: due applicazioni tema = un solo blocco 44px.
printf '1\n' > "$TMP/.config/labwc/touchscreen.enabled"
for _ in 1 2; do
    HOME="$TMP" LABWC_Q4OS_SHARE="$TMP/share" LABWC_Q4OS_SKIP_LOGIN=1 \
        bash scripts/labwc-theme-apply nordic-cobalt --no-reload --quiet >/dev/null 2>&1
done
touch_blocks="$(grep -c '^window.button.width: 44$' "$TMP/.config/labwc/themerc-override" 2>/dev/null || true)"
if [ "$touch_blocks" = "1" ]; then
    pass "blocco touch nel tema (idempotente)"
else
    bad "blocco touch nel tema: $touch_blocks occorrenze (attesa 1)"
fi
rm -f "$TMP/.config/labwc/touchscreen.enabled"

if HOME="$TMP" python3 scripts/render-menu.py --render >/dev/null; then
    pass "menu.xml generato"
else
    bad "menu.xml non generato"
fi
if xmllint --noout "$TMP/.local/share/icons/labwc-q4os/scalable/apps/utilities-terminal.svg"; then
    pass "icona SVG valida"
else
    bad "icona SVG non valida"
fi
if xmllint --noout "$TMP/.config/labwc/menu.xml"; then
    pass "menu.xml XML valido"
else
    bad "menu.xml XML non valido"
fi
if python3 - "$TMP/.config/labwc/menu.xml" <<'PY'
import sys, unicodedata, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
# desktop-menu: la scala schermo e' volutamente in cima (labwc non ha scroll).
skip = {"root-menu", "client-menu", "client-send-to-desktop-menu", "desktop-menu"}
def key(text):
    normalized = unicodedata.normalize("NFKD", text.casefold())
    return "".join(c for c in normalized if not unicodedata.combining(c))
def walk(menu):
    labels = [child.get("label", "") for child in menu if child.tag in ("item", "menu")]
    if menu.get("id") not in skip and labels != sorted(labels, key=key):
        raise SystemExit(1)
    for child in menu:
        if child.tag == "menu":
            walk(child)
walk(root)
PY
then
    pass "tutti i sottomenu in ordine alfabetico"
else
    bad "sottomenu non in ordine alfabetico"
fi
if HOME="$TMP" python3 scripts/render-menu.py --json | jq -e '.categories|length > 0' >/dev/null; then
    pass "render-menu.py --json"
else
    bad "render-menu.py --json"
fi

# --- 7. shellcheck (opzionale) ----------------------------------------------
check "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x -S warning install.sh bootstrap.sh scripts/lib.sh \
        scripts/labwc-theme-apply scripts/labwc-theme-switcher scripts/labwc-menu-editor \
        scripts/labwc-reload scripts/labwc-generate-wallpapers scripts/labwc-help \
        scripts/labwc-screenshot scripts/labwc-doctor scripts/labwc-update-check \
        scripts/labwc-update-copy scripts/labwc-update-popup scripts/labwc-update-run \
        scripts/labwc-update-toggle \
        scripts/labwc-minimized scripts/labwc-cage scripts/labwc-cage-app \
        scripts/labwc-freetube scripts/labwc-freetube-cage scripts/labwc-cage-help scripts/labwc-return \
        scripts/labwc-login-theme-apply scripts/labwc-session-launch \
        scripts/labwc-desktop scripts/labwc-desktop-state \
        scripts/labwc-desktop-status scripts/labwc-desktop-menu \
        scripts/labwc-power-menu scripts/labwc-sysinfo \
        scripts/labwc-touchscreen \
        scripts/labwc-session-start scripts/validate.sh; then
        pass "shellcheck"
    else
        bad "shellcheck"
    fi
else
    printf '[  skip ] shellcheck non installato\n'
fi

if [ "$fail" -ne 0 ]; then
    printf '\nValidazione FALLITA.\n' >&2
    exit 1
fi

printf '\nValidazione completata: tutto ok.\n'
