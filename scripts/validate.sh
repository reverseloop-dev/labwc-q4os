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
if PYTHONPYCACHEPREFIX="$PYCACHE_DIR" python3 -m py_compile scripts/generate-wallpapers.py scripts/render-menu.py scripts/labwc-zram; then
    pass "generate-wallpapers.py, render-menu.py, labwc-zram"
else
    bad "py_compile"
fi
rm -rf "$PYCACHE_DIR"
if python3 scripts/labwc-zram --status >/dev/null 2>&1; then
    pass "labwc-zram --status"
else
    bad "labwc-zram --status"
fi

# --- 3. JSON -----------------------------------------------------------------
check "JSON (Waybar, wlogout)"
if jq empty configs/waybar/config.jsonc; then pass "waybar/config.jsonc"; else bad "waybar/config.jsonc"; fi
if jq empty configs/wlogout/layout; then pass "wlogout/layout"; else bad "wlogout/layout"; fi

# --- 4. XML ------------------------------------------------------------------
check "XML (labwc rc.xml)"
if xmllint --noout configs/labwc/rc.xml; then pass "labwc/rc.xml"; else bad "labwc/rc.xml"; fi

# --- 5. permessi eseguibili -------------------------------------------------
check "permessi eseguibili"
for f in install.sh bootstrap.sh scripts/labwc-theme-apply scripts/labwc-theme-switcher \
         scripts/labwc-menu-editor scripts/labwc-reload scripts/labwc-generate-wallpapers \
         scripts/labwc-help scripts/labwc-screenshot scripts/labwc-zram scripts/labwc-doctor \
         scripts/labwc-session-start scripts/validate.sh scripts/generate-wallpapers.py scripts/render-menu.py; do
    if [ -x "$f" ]; then pass "$f"; else bad "$f non eseguibile"; fi
done

# --- 6. smoke test in HOME temporanea ---------------------------------------
check "smoke test tema + menu in HOME temporanea"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/share/themes" "$TMP/share/templates" "$TMP/share/scripts" "$TMP/share/wallpapers"
cp -a configs/themes/. "$TMP/share/themes/"
cp configs/waybar/style.css.in "$TMP/share/templates/waybar-style.css"
cp configs/fuzzel/fuzzel.ini.in "$TMP/share/templates/fuzzel.ini"
cp configs/mako/config.in "$TMP/share/templates/mako-config"
cp configs/wlogout/style.css.in "$TMP/share/templates/wlogout-style.css"

for theme in nordic-cobalt muted-crimson sage-emerald; do
    if HOME="$TMP" LABWC_Q4OS_SHARE="$TMP/share" \
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
done

if HOME="$TMP" python3 scripts/render-menu.py --render >/dev/null; then
    pass "menu.xml generato"
else
    bad "menu.xml non generato"
fi
if xmllint --noout "$TMP/.config/labwc/menu.xml"; then
    pass "menu.xml XML valido"
else
    bad "menu.xml XML non valido"
fi

# --- 7. shellcheck (opzionale) ----------------------------------------------
check "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x -S warning install.sh bootstrap.sh scripts/lib.sh \
        scripts/labwc-theme-apply scripts/labwc-theme-switcher scripts/labwc-menu-editor \
        scripts/labwc-reload scripts/labwc-generate-wallpapers scripts/labwc-help \
        scripts/labwc-screenshot scripts/labwc-doctor \
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
