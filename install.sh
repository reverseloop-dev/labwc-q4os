#!/usr/bin/env bash
# =============================================================================
#  labwc-q4os — installer completo per Q4OS / Debian
#  https://github.com/reverseloop-dev/labwc-q4os
#
#  Installa e configura:
#    labwc + Waybar + Fuzzel + swaybg + Mako + wlogout (o Noctalia v5)
#    tre temi completi (blu, rosso tenue, verde salvia)
#    tre sfondi moderni con firma reverseloop-dev
#    menu dinamico con app preferite e help integrato
#    ottimizzazione zram / swappiness (interattiva)
#
#  Uso:
#    ./install.sh
#    ./install.sh --theme blue --yes
#    ./install.sh --theme red --no-zram --yes
#    ./install.sh --help
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED_ORIGIN="https://github.com/reverseloop-dev/labwc-q4os"
if [ -d "$REPO_DIR/.git" ] && [ "${LABWC_Q4OS_ALLOW_UNVERIFIED:-0}" != "1" ]; then
    repo_origin="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
    case "$repo_origin" in
        "$EXPECTED_ORIGIN"|"$EXPECTED_ORIGIN.git") ;;
        *)
            printf '[labwc-q4os] ERRORE: repository non attendibile: %s\n' "${repo_origin:-nessuno}" >&2
            printf "Atteso: %s\nPer un fork consapevole: LABWC_Q4OS_ALLOW_UNVERIFIED=1\n" "$EXPECTED_ORIGIN" >&2
            exit 1
            ;;
    esac
fi
# shellcheck source=scripts/lib.sh
source "$REPO_DIR/scripts/lib.sh"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
APPDATA="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/labwc-q4os"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/labwc-q4os"
BIN="$HOME/.local/bin"
BACKUP_DIR="$STATE/backups/$(date +%Y%m%d-%H%M%S)"

THEME=""
ASSUME_YES=0
ENABLE_ZRAM=""
ENABLE_SWAPPINESS=""
ENABLE_TOUCH=""
WANT_LOOKSWITCHER=""
WANT_BROWSER=""
REMOVE_BROWSER=""
GUI_CHOICES=0
WANT_QPDFVIEW=""
WANT_FREETUBE=""
QUICK_UPDATE=""
INSTALL_OPTIONS="${LABWC_Q4OS_OPTIONS:-/etc/labwc-q4os/install-options}"
PARAM_FLAGS=0
SWAPPINESS_VALUE=""
SKIP_APT=0
FORCE_OS=0
WANT_SDDM=""
SDDM_ENABLED=0
XKB_LAYOUT=""
WANT_SHELL=""

usage() {
    cat <<'EOF'
labwc-q4os — installer per Q4OS / Debian

Uso: ./install.sh [opzioni]

Opzioni:
  --theme NOME        Tema iniziale: blu|blue|nordic-cobalt
                      rosso|red|muted-crimson
                      verde|green|sage-emerald
  --yes               Non chiedere conferma (zram, swappiness e SDDM su TDM;
                      tema corrente o blu)
  --zram / --no-zram  Attiva o disattiva zram senza prompt
  --keyboard LAYOUT  Layout tastiera labwc/login (es. it, us, it,us)
  --touch             Installa tastiera su schermo (wvkbd) e gesti touch (lisgd)
  --no-touch          Disattiva la configurazione touchscreen
  --lookswitcher      Installa LookSwitcher, selettore temi per Trinity (solo Trinity)
  --no-lookswitcher   Non proporre/installare LookSwitcher
  --browser NOME      Browser: chromium|firefox|both|none (default: chromium)
  --chromium          Scegli Chromium (web app, Chrome Web Store; piu' RAM)
  --firefox           Scegli Firefox ESR (leggero, privacy; meno RAM)
  --no-chromium       Nessun browser (compatibilità)
  --no-browser        Nessun browser
  --qpdfview          Installa qpdfview (lettore PDF leggero) senza chiedere
  --no-qpdfview       Non installare qpdfview
  --freetube          Installa FreeTube dal repo APT
  --no-freetube       Non installare FreeTube
  --quick             Aggiorna senza domande, usando le opzioni salvate
  --configure         Chiedi comunque tutti i parametri prima di aggiornare
  --shell NOME        Shell desktop: waybar|noctalia (default: waybar)
  --swappiness N      Imposta vm.swappiness a N (0-200)
  --no-swappiness     Non modificare vm.swappiness
  --sddm              Installa e attiva SDDM se TDM non supporta Wayland
  --keep-tdm          Non toccare il display manager (TDM resta attivo)
  --skip-apt          Non installare pacchetti (solo configurazione)
  --force-os          Procedi anche su distribuzioni non Debian/Q4OS
  -h, --help          Mostra questo aiuto

Lo script va eseguito come utente normale, non come root: usera' sudo
solo per apt e per i file di sistema. Le configurazioni esistenti vengono
salvate in ~/.local/share/labwc-q4os/backups/.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --theme)
            [ "$#" -ge 2 ] || die "--theme richiede un valore"
            THEME="$2"; shift 2 ;;
        --theme=*) THEME="${1#*=}"; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        --zram) ENABLE_ZRAM=1; shift ;;
        --no-zram) ENABLE_ZRAM=0; shift ;;
        --swappiness)
            [ "$#" -ge 2 ] || die "--swappiness richiede un numero"
            SWAPPINESS_VALUE="$2"; ENABLE_SWAPPINESS=1; shift 2 ;;
        --swappiness=*) SWAPPINESS_VALUE="${1#*=}"; ENABLE_SWAPPINESS=1; shift ;;
        --keyboard)
            [ "$#" -ge 2 ] || die "--keyboard richiede un valore"
            XKB_LAYOUT="$2"; shift 2 ;;
        --keyboard=*) XKB_LAYOUT="${1#*=}"; shift ;;
        --no-swappiness) ENABLE_SWAPPINESS=0; shift ;;
        --touch) ENABLE_TOUCH=1; shift ;;
        --no-touch) ENABLE_TOUCH=0; shift ;;
        --lookswitcher) WANT_LOOKSWITCHER=1; shift ;;
        --no-lookswitcher) WANT_LOOKSWITCHER=0; shift ;;
        --browser)
            [ "$#" -ge 2 ] || die "--browser richiede un valore (chromium|firefox|none)"
            WANT_BROWSER="$2"; shift 2 ;;
        --browser=*) WANT_BROWSER="${1#*=}"; shift ;;
        --chromium) WANT_BROWSER=chromium; shift ;;
        --firefox|--firefox-esr) WANT_BROWSER=firefox; shift ;;
        --both-browsers) WANT_BROWSER=both; shift ;;
        --no-chromium|--no-browser) WANT_BROWSER=none; shift ;;
        --qpdfview) WANT_QPDFVIEW=1; shift ;;
        --no-qpdfview) WANT_QPDFVIEW=0; shift ;;
        --freetube) WANT_FREETUBE=1; shift ;;
        --no-freetube) WANT_FREETUBE=0; shift ;;
        --quick) QUICK_UPDATE=1; shift ;;
        --configure) QUICK_UPDATE=0; shift ;;
        --shell)
            [ "$#" -ge 2 ] || die "--shell richiede un valore (waybar|noctalia)"
            WANT_SHELL="$2"; shift 2 ;;
        --shell=*) WANT_SHELL="${1#*=}"; shift ;;
        --skip-apt) SKIP_APT=1; shift ;;
        --sddm) WANT_SDDM=1; shift ;;
        --keep-tdm) WANT_SDDM=0; shift ;;
        --force-os) FORCE_OS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Opzione sconosciuta: $1 (usa --help)" ;;
    esac
done

if [ -n "$WANT_BROWSER" ]; then
    case "$WANT_BROWSER" in
        chromium|firefox|both|none) ;;
        librewolf) WANT_BROWSER=firefox; REMOVE_BROWSER=librewolf ;;
        *) die "Valore --browser non valido: $WANT_BROWSER (chromium|firefox|none)" ;;
    esac
fi

if [ -n "$WANT_SHELL" ]; then
    case "$WANT_SHELL" in
        waybar|noctalia) ;;
        *) die "Valore --shell non valido: $WANT_SHELL (waybar|noctalia)" ;;
    esac
fi

if [ -n "$THEME$ENABLE_ZRAM$ENABLE_SWAPPINESS$ENABLE_TOUCH$WANT_LOOKSWITCHER$WANT_SHELL$WANT_SDDM$XKB_LAYOUT$WANT_BROWSER$WANT_QPDFVIEW$WANT_FREETUBE$SWAPPINESS_VALUE" ]; then
    PARAM_FLAGS=1
fi

option_value() {
    [ -r "$INSTALL_OPTIONS" ] || return 1
    local value
    value="$(sed -n "s/^$1=//p" "$INSTALL_OPTIONS" | head -n1)"
    [ -n "$value" ] && printf '%s' "$value"
}

load_saved_options() {
    [ -r "$INSTALL_OPTIONS" ] || return 1
    local value

    value="$(option_value SHELL || true)"
    case "$value" in waybar|noctalia) WANT_SHELL="$value" ;; esac
    value="$(option_value TOUCH || true)"
    case "$value" in 0|1) ENABLE_TOUCH="$value" ;; esac
    value="$(option_value LOOKSWITCHER || true)"
    case "$value" in 0|1) WANT_LOOKSWITCHER="$value" ;; esac
    value="$(option_value ZRAM || true)"
    case "$value" in 0|1) ENABLE_ZRAM="$value" ;; esac
    value="$(option_value SWAPPINESS_ENABLED || true)"
    case "$value" in 0|1) ENABLE_SWAPPINESS="$value" ;; esac
    value="$(option_value SWAPPINESS_VALUE || true)"
    [ -n "$value" ] && SWAPPINESS_VALUE="$value"
    value="$(option_value THEME || true)"
    case "$value" in nordic-cobalt|muted-crimson|sage-emerald) THEME="$value" ;; esac
    value="$(option_value KEYBOARD || true)"
    if [[ "$value" =~ ^[a-z]{2}(-[a-zA-Z0-9]+)?(,[a-z]{2}(-[a-zA-Z0-9]+)?)*$ ]]; then
        XKB_LAYOUT="$value"
    fi
    value="$(option_value BROWSER || true)"
    case "$value" in
        chromium|firefox|both|none) WANT_BROWSER="$value" ;;
        librewolf) WANT_BROWSER=firefox; REMOVE_BROWSER=librewolf ;;
    esac
    if [ -z "$WANT_BROWSER" ]; then
        # Migrazione dalle vecchie opzioni: CHROMIUM=1/0.
        value="$(option_value CHROMIUM || true)"
        case "$value" in
            1) WANT_BROWSER=chromium ;;
            0) WANT_BROWSER=none ;;
        esac
    fi
    value="$(option_value QPDFVIEW || true)"
    case "$value" in 0|1) WANT_QPDFVIEW="$value" ;; esac
    value="$(option_value FREETUBE || true)"
    case "$value" in 0|1) WANT_FREETUBE="$value" ;; esac
    value="$(option_value KEEP_TDM || true)"
    case "$value" in
        1) WANT_SDDM=0 ;;
        0) WANT_SDDM=1 ;;
    esac
    return 0
}

# Prima domanda dell'aggiornamento: modificare i parametri o usare quelli
# salvati (nessuna domanda, solo password sudo). Su prima installazione non
# esiste il file opzioni e si procede con la configurazione normale.
if [ "$ASSUME_YES" -eq 0 ] && [ -z "$QUICK_UPDATE" ] && [ "$PARAM_FLAGS" -eq 0 ] &&
    [ -r "$INSTALL_OPTIONS" ] && [ -r /dev/tty ]; then
    quick_gui=""
    if [ "${LABWC_Q4OS_NO_GUI:-0}" != "1" ]; then
        quick_gui="$(gui_quick_prompt 2>/dev/null)" || true
    fi
    case "$quick_gui" in
        QUICK=1) QUICK_UPDATE=1 ;;
        QUICK=0) QUICK_UPDATE=0 ;;
        *)
            note "Sì: riapri le scelte. No: usa le opzioni salvate e aggiorna subito."
            if ask_yes_no "Vuoi modificare i parametri prima di aggiornare? (No = usa le opzioni salvate e aggiorna subito)" no; then
                QUICK_UPDATE=0
            else
                QUICK_UPDATE=1
            fi
            ;;
    esac
fi
if [ "$QUICK_UPDATE" = "1" ]; then
    if load_saved_options; then
        ASSUME_YES=1
        info "Aggiornamento rapido: uso le opzioni salvate, nessuna domanda."
    else
        warn "Nessuna configurazione salvata: procedo con le domande."
        QUICK_UPDATE=0
    fi
elif [ "$QUICK_UPDATE" = "0" ]; then
    info "Modalità configurazione: tutte le domande verranno proposte."
fi

normalize_theme() {
    case "${1,,}" in
        blue|blu|nordic|nordic-cobalt) printf 'nordic-cobalt' ;;
        red|rosso|muted|muted-crimson|crimson) printf 'muted-crimson' ;;
        green|verde|sage|sage-emerald|emerald) printf 'sage-emerald' ;;
        *) return 1 ;;
    esac
}

theme_label() {
    case "$1" in
        nordic-cobalt) printf 'Blu — Nordic Cobalt' ;;
        muted-crimson) printf 'Rosso tenue — Muted Crimson' ;;
        sage-emerald) printf 'Verde salvia — Sage Emerald' ;;
        *) printf '%s' "$1" ;;
    esac
}

browser_label() {
    case "$1" in
        chromium) printf 'Chromium' ;;
        firefox) printf 'Firefox ESR' ;;
        both) printf 'Chromium + Firefox ESR' ;;
        *) printf 'nessuno' ;;
    esac
}

# Chiede il wizard GTK3. Restituisce 0 con le scelte, 1 se annullato,
# 2 se GTK/display non disponibile (in quel caso si usa la shell).
run_install_wizard() {
    [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || return 2
    command -v python3 >/dev/null 2>&1 || return 2
    [ -x "$REPO_DIR/scripts/labwc-install-wizard" ] || return 2

    local theme_default="${THEME:-}"
    if [ -z "$theme_default" ] && [ -r "$CONFIG/labwc/theme" ]; then
        theme_default="$(tr -d '[:space:]' < "$CONFIG/labwc/theme")"
    fi
    [ -n "$theme_default" ] || theme_default="nordic-cobalt"

    local touch_now=0
    [ -n "$("$REPO_DIR/scripts/labwc-touchscreen" 2>/dev/null | tr -d '[:space:]' || true)" ] &&
        touch_now=1
    local sddm_available=0
    if [ "$DM_NAME" = "tdm" ] || [ "$DM_NAME" = "tdm-trinity" ]; then
        sddm_available=1
    fi
    local chromium_here=0 firefox_here=0
    if have chromium || have chromium-browser; then chromium_here=1; fi
    if have firefox-esr; then firefox_here=1; fi

    local browser_default="${WANT_BROWSER:-}"
    if [ -z "$browser_default" ]; then
        if [ "$chromium_here" -eq 0 ] && [ "$firefox_here" -eq 1 ]; then
            browser_default="firefox"
        else
            browser_default="chromium"
        fi
    fi
    local shell_default="${WANT_SHELL:-waybar}"
    local look_default="${WANT_LOOKSWITCHER:-0}"
    local sddm_default=0
    if [ "$sddm_available" -eq 1 ]; then sddm_default=1; fi
    local trinity_here=0
    if command -v starttde >/dev/null 2>&1 || [ -d /etc/trinity ] ||
        dpkg -s tdebase-trinity >/dev/null 2>&1; then
        trinity_here=1
    fi

    python3 "$REPO_DIR/scripts/labwc-install-wizard" \
        --theme "$theme_default" --themes-dir "$REPO_DIR/configs/themes" \
        --keyboard "${XKB_LAYOUT:-$DETECTED_LAYOUT}" \
        --browser "$browser_default" --shell "$shell_default" \
        --zram 1 --swappiness 1 --touch "$touch_now" \
        --lookswitcher "$look_default" --lookswitcher-available "$trinity_here" \
        --qpdfview 1 --freetube 1 \
        --sddm "$sddm_default" --sddm-available "$sddm_available" \
        --chromium-installed "$chromium_here" --firefox-installed "$firefox_here"
}

apply_wizard_output() {
    local line key value
    while IFS='=' read -r key value; do
        case "$key" in
            BROWSER) case "$value" in chromium|firefox|both|none) WANT_BROWSER="$value" ;; esac ;;
            REMOVE_BROWSER) case "$value" in chromium|firefox) REMOVE_BROWSER="$value" ;; esac ;;
            SHELL) case "$value" in waybar|noctalia) WANT_SHELL="$value" ;; esac ;;
            ZRAM) case "$value" in 0|1) ENABLE_ZRAM="$value" ;; esac ;;
            SWAPPINESS) case "$value" in 0|1) ENABLE_SWAPPINESS="$value" ;; esac ;;
            TOUCH) case "$value" in 0|1) ENABLE_TOUCH="$value" ;; esac ;;
            LOOKSWITCHER) case "$value" in 0|1) WANT_LOOKSWITCHER="$value" ;; esac ;;
            QPDFVIEW) case "$value" in 0|1) WANT_QPDFVIEW="$value" ;; esac ;;
            FREETUBE) case "$value" in 0|1) WANT_FREETUBE="$value" ;; esac ;;
            THEME) THEME="$value" ;;
            KEYBOARD) XKB_LAYOUT="$value" ;;
            SDDM) case "$value" in 0|1) WANT_SDDM="$value" ;; esac ;;
        esac
    done <<< "$1"
}

gui_quick_prompt() {
    [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || return 2
    command -v python3 >/dev/null 2>&1 || return 2
    [ -x "$REPO_DIR/scripts/labwc-install-wizard" ] || return 2
    local quick_theme="nordic-cobalt"
    if [ -r "$CONFIG/labwc/theme" ]; then
        quick_theme="$(tr -d '[:space:]' < "$CONFIG/labwc/theme" || true)"
    fi
    case "$quick_theme" in
        nordic-cobalt|muted-crimson|sage-emerald) ;;
        *) quick_theme="nordic-cobalt" ;;
    esac
    python3 "$REPO_DIR/scripts/labwc-install-wizard" --quick-prompt \
        --theme "$quick_theme" --themes-dir "$REPO_DIR/configs/themes"
}

# -----------------------------------------------------------------------------
# Controlli preliminari
# -----------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ] && [ "${LABWC_Q4OS_ALLOW_ROOT:-0}" != "1" ]; then
    die "Non eseguire lo script come root. Usa un utente normale: verra' usato sudo."
fi
if [ "$(id -u)" -eq 0 ]; then
    warn "Esecuzione root forzata da LABWC_Q4OS_ALLOW_ROOT=1 (solo test/container)."
fi

if ! command -v sudo >/dev/null 2>&1; then
    die "sudo non trovato. Installalo o esegui lo script da un utente amministratore."
fi

if ! command -v apt-get >/dev/null 2>&1; then
    [ "$FORCE_OS" -eq 1 ] || die "apt-get non trovato: questo installer richiede Q4OS/Debian."
fi

OS_ID=""; OS_LIKE=""; OS_NAME="sconosciuto"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-}"; OS_LIKE="${ID_LIKE:-}"; OS_NAME="${PRETTY_NAME:-$OS_ID}"
fi

case " $OS_ID $OS_LIKE " in
    *debian*|*q4os*|*ubuntu*)
        ok "Sistema rilevato: $OS_NAME"
        ;;
    *)
        if [ "$FORCE_OS" -eq 1 ]; then
            warn "Sistema non Debian/Q4OS ($OS_NAME): proseguo per richiesta (--force-os)."
        else
            die "Sistema non supportato ($OS_NAME). Q4OS/Debian richiesto (usa --force-os per forzare)."
        fi
        ;;
esac

DM_NAME=""
if [ -e /etc/systemd/system/display-manager.service ]; then
    DM_NAME="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
elif [ -r /etc/X11/default-display-manager ]; then
    DM_NAME="$(basename "$(cat /etc/X11/default-display-manager 2>/dev/null)" )"
fi

# Login gestito da SDDM con tema Plasma/Breeze (tipico di Q4OS Plasma)?
# In quel caso va forzato il nostro tema e la sessione Labwc, altrimenti
# labwc puo' avviarsi senza configurazione (schermo nero, menu minimo).
PLASMA_LOGIN=0
if command -v sddm >/dev/null 2>&1 &&
    { [ -f /usr/share/wayland-sessions/plasma.desktop ] ||
      [ -f /usr/share/xsessions/plasma.desktop ] ||
      [ -d /usr/share/plasma ]; }; then
    current_login_theme=""
    for sddm_conf in /etc/sddm.conf /etc/sddm.conf.d/*.conf; do
        [ -r "$sddm_conf" ] || continue
        value="$(sed -n 's/^[[:space:]]*Current=//p' "$sddm_conf" | tail -n1)"
        [ -n "$value" ] && current_login_theme="$value"
    done
    case "$current_login_theme" in
        labwc-q4os) ;;
        *) PLASMA_LOGIN=1 ;;
    esac
fi

detect_xkb_layout() {
    local layout=""
    if [ -r /etc/default/keyboard ]; then
        layout="$(sed -n 's/^XKBLAYOUT="\?\([^" ]*\)"\?.*/\1/p' /etc/default/keyboard | head -n1)"
    fi
    if [ -z "$layout" ] && command -v localectl >/dev/null 2>&1; then
        layout="$(localectl status 2>/dev/null | sed -n 's/.*X11 Layout: *//p' | head -n1)"
    fi
    if [ -z "$layout" ] || [ "$layout" = "us" ]; then
        case "${LANG:-}${LC_ALL:-}" in
            it*) layout="it" ;;
            *) [ -z "$layout" ] && layout="us" ;;
        esac
    fi
    printf '%s' "$layout"
}

DETECTED_LAYOUT="$(detect_xkb_layout)"
DETECTED_LAYOUT="${DETECTED_LAYOUT:-us}"

if [ -n "$XKB_LAYOUT" ]; then
    XKB_LAYOUT="${XKB_LAYOUT,,}"
fi


if [ -r "$CONFIG/labwc/theme" ]; then
    current_theme="$(tr -d '[:space:]' < "$CONFIG/labwc/theme")"
    case "$current_theme" in
        nordic-cobalt|muted-crimson|sage-emerald)
            [ -z "$THEME" ] && THEME="$current_theme" ;;
    esac
fi

if [ ! -d /dev/dri ]; then
    warn "/dev/dri non trovato: Wayland potrebbe non avviarsi. Verifica i driver GPU."
fi
if [ -n "${XDG_SESSION_TYPE:-}" ]; then
    info "Sessione corrente: $XDG_SESSION_TYPE (Labwc e' una sessione Wayland separata)."
fi

if [ -n "$THEME" ]; then
    THEME="$(normalize_theme "$THEME")" || die "Tema non valido: $THEME (blu, rosso, verde)"
fi

if [ -n "$SWAPPINESS_VALUE" ]; then
    [[ "$SWAPPINESS_VALUE" =~ ^[0-9]+$ ]] || die "--swappiness richiede un numero tra 0 e 200"
    SWAPPINESS_VALUE=$((10#$SWAPPINESS_VALUE))
    if [ "$SWAPPINESS_VALUE" -lt 0 ] || [ "$SWAPPINESS_VALUE" -gt 200 ]; then
        die "--swappiness deve essere tra 0 e 200"
    fi
fi

printf '\n%s%s labwc-q4os %s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
printf '%sDesktop Wayland moderno per Q4OS / Debian%s\n' "$C_DIM" "$C_RESET"
printf '%sreverseloop-dev · https://github.com/reverseloop-dev/labwc-q4os%s\n\n' "$C_DIM" "$C_RESET"

if [ "$ASSUME_YES" -eq 0 ] && [ "$QUICK_UPDATE" != "1" ] && [ "$PARAM_FLAGS" -eq 0 ] &&
    [ "${LABWC_Q4OS_NO_GUI:-0}" != "1" ] && [ -r /dev/tty ]; then
    if wizard_out="$(run_install_wizard)"; then
        wizard_rc=0
    else
        wizard_rc=$?
    fi
    if [ "$wizard_rc" -eq 0 ] && [ -n "$wizard_out" ]; then
        apply_wizard_output "$wizard_out"
        GUI_CHOICES=1
        info "Scelte della finestra acquisite."
    elif [ "$wizard_rc" -eq 1 ]; then
        die "Installazione annullata dalla finestra di scelta."
    else
        warn "GUI non disponibile: proseguo con le domande nella shell."
    fi
fi

# FreeTube: client YouTube con GUI, dal pacchetto .deb ufficiale.
if [ -z "$WANT_FREETUBE" ]; then
    if [ "$SKIP_APT" -eq 1 ]; then
        WANT_FREETUBE=0
    elif [ "$QUICK_UPDATE" = "1" ]; then
        WANT_FREETUBE=0
    elif [ "$ASSUME_YES" -eq 1 ]; then
        WANT_FREETUBE=1
    else
        note "FreeTube è un client YouTube open source con interfaccia grafica."
        note "Usa un repository APT dedicato (GHaaAPT): circa 100 MB e un minuto."
        note "Niente Flatpak, niente Flathub; aggiornamenti con apt."
        if ask_yes_no "Installare FreeTube?" yes; then
            WANT_FREETUBE=1
        else
            WANT_FREETUBE=0
        fi
    fi
fi

if [ -z "$XKB_LAYOUT" ]; then
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -r /dev/tty ]; then
        XKB_LAYOUT="$DETECTED_LAYOUT"
    else
        note "Layout per la sessione Labwc e per il login: it, us oppure it,us."
        XKB_LAYOUT="$(ask_input "Layout tastiera (it, us, it,us)" "$DETECTED_LAYOUT" '^[a-z]{2}(-[a-zA-Z0-9]+)?(,[a-z]{2}(-[a-zA-Z0-9]+)?)*$')"
        XKB_LAYOUT="${XKB_LAYOUT,,}"
    fi
fi
if ! [[ "$XKB_LAYOUT" =~ ^[a-z]{2}(-[a-zA-Z0-9]+)?(,[a-z]{2}(-[a-zA-Z0-9]+)?)*$ ]]; then
    die "Layout tastiera non valido: $XKB_LAYOUT (esempi: it, us, it,us)"
fi
XKB_PRIMARY="${XKB_LAYOUT%%,*}"
if [[ "$XKB_LAYOUT" == *","* ]]; then
    XKB_OPTIONS="grp:alt_shift_toggle"
else
    XKB_OPTIONS=""
fi


# -----------------------------------------------------------------------------
# Scelte prestazioni
# -----------------------------------------------------------------------------
if [ -z "$ENABLE_ZRAM" ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
        ENABLE_ZRAM=1
    else
        note "zram comprime parte della RAM: più reattività su PC con poca memoria."
        if ask_yes_no "Attivare zram (RAM compressa zstd, 50%) per un sistema piu' reattivo?" yes; then
            ENABLE_ZRAM=1
        else
            ENABLE_ZRAM=0
        fi
    fi
fi

if [ -z "$ENABLE_SWAPPINESS" ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
        ENABLE_SWAPPINESS=1
    else
        note "swappiness regola quanto il sistema usa lo swap; con zram conviene 100."
        if ask_yes_no "Configurare vm.swappiness e vfs_cache_pressure in modo persistente?" yes; then
            ENABLE_SWAPPINESS=1
        else
            ENABLE_SWAPPINESS=0
        fi
    fi
fi

if [ "$ENABLE_ZRAM" -eq 1 ]; then
    info "zram: zstd, 50% della RAM, priorita' 100. La RAM compressa evita I/O su disco."
    if [ -z "$SWAPPINESS_VALUE" ]; then
        SWAPPINESS_VALUE=100
    fi
    info "Con zram conviene vm.swappiness=100: lo swap e' in RAM compressa, quindi veloce."
else
    if [ -z "$SWAPPINESS_VALUE" ] && [ "$ENABLE_SWAPPINESS" -eq 1 ]; then
        SWAPPINESS_VALUE=10
    fi
    info "zram restera' installato e configurato ma disattivato; potrai accenderlo dal menu ZRAM."
    [ "$ENABLE_SWAPPINESS" -eq 1 ] && info "Senza zram: vm.swappiness=10 evita swap su disco prematuri."
fi
info "vm.vfs_cache_pressure=50 mantiene in cache inode/dentry e riduce il lavoro del disco."

# Touchscreen: tastiera su schermo wvkbd + gesti lisgd, testi e pulsanti grandi.
if [ -z "$ENABLE_TOUCH" ]; then
    touch_default="no"
    touch_devs="$("$REPO_DIR/scripts/labwc-touchscreen" 2>/dev/null | tr '\n' ' ' || true)"
    if [ -n "$touch_devs" ]; then
        touch_default="yes"
        info "Touchscreen rilevato: ${touch_devs% }"
    fi
    if [ "$ASSUME_YES" -eq 1 ]; then
        [ "$touch_default" = "yes" ] && ENABLE_TOUCH=1 || ENABLE_TOUCH=0
    else
        note "Touchscreen: installa wvkbd e lisgd, con tastiera richiamabile dal basso."
        if ask_yes_no "Il PC che stai usando ha un touchscreen? Installa tastiera su schermo e gesti touch" "$touch_default"; then
            ENABLE_TOUCH=1
        else
            ENABLE_TOUCH=0
        fi
    fi
fi
if [ "$ENABLE_TOUCH" -eq 1 ]; then
    info "Touchscreen: wvkbd (tastiera richiamabile con swipe dal basso), lisgd, scaling 1.25."
fi

# LookSwitcher: selettore di temi per la sessione Trinity (NON per labwc).
trinity_present=0
if command -v starttde >/dev/null 2>&1 || [ -d /etc/trinity ] ||
    dpkg -s tdebase-trinity >/dev/null 2>&1; then
    trinity_present=1
fi
if [ -z "$WANT_LOOKSWITCHER" ]; then
    if [ "$trinity_present" -eq 0 ]; then
        WANT_LOOKSWITCHER=0
        info "LookSwitcher: Trinity non rilevato, domanda saltata."
    elif [ "$ASSUME_YES" -eq 1 ]; then
        WANT_LOOKSWITCHER=0
    else
        note "LookSwitcher serve solo alla sessione Trinity e non modifica labwc."
        if ask_yes_no "Installare LookSwitcher (selettore di temi Q4OS), SOLO per la sessione Trinity? Non cambia labwc" no; then
            WANT_LOOKSWITCHER=1
        else
            WANT_LOOKSWITCHER=0
        fi
    fi
fi
if [ "$WANT_LOOKSWITCHER" -eq 1 ] && [ "$trinity_present" -eq 1 ]; then
    info "LookSwitcher: verra' installato per Trinity; labwc continua a usare i suoi tre temi."
elif [ "$trinity_present" -eq 0 ]; then
    WANT_LOOKSWITCHER=0
fi

# Shell desktop: Waybar + Fuzzel (default) oppure Noctalia v5.
if [ -z "$WANT_SHELL" ]; then
    shell_default="waybar"
    if [ -r "$CONFIG/labwc/shell" ]; then
        current_shell="$(tr -d '[:space:]' < "$CONFIG/labwc/shell")"
        case "$current_shell" in
            waybar|noctalia) shell_default="$current_shell" ;;
        esac
    fi
    if [ "$ASSUME_YES" -eq 1 ]; then
        WANT_SHELL="$shell_default"
    else
        info "Shell desktop: scegli come avviare barra, launcher e notifiche."
        info "  1) Waybar + Fuzzel (default): componenti separati, leggerissimi su CPU/RAM/GPU,"
        info "     gia' configurati dal progetto; Fuzzel/Zenity usati anche dagli strumenti."
        info "  2) Noctalia v5: shell unica (barra, launcher, notifiche, centro di controllo,"
        info "     sfondi, lock), nativa OpenGL ES: piu' moderna e coerente ma piu' pesante"
        info "     su RAM/GPU; repository APT di terze parti, solo Debian/Q4OS (amd64/arm64)."
        default_choice=1
        [ "$shell_default" = "noctalia" ] && default_choice=2
        note "Waybar+Fuzzel è la più leggera; Noctalia integra barra, launcher e notifiche."
        choice="$(ask_choice "Shell desktop (1=Waybar+Fuzzel, 2=Noctalia v5)" "$default_choice" 1 2)"
        case "$choice" in
            1) WANT_SHELL=waybar ;;
            2) WANT_SHELL=noctalia ;;
        esac
    fi
fi

if [ "$DM_NAME" = "tdm" ] || [ "$DM_NAME" = "tdm-trinity" ]; then
    if [ -z "$WANT_SDDM" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            WANT_SDDM=1
        else
            note "SDDM permette di scegliere Labwc al login; TDM resta installato."
            if ask_yes_no "TDM non supporta Wayland. Installare e attivare SDDM per scegliere Labwc al login?" yes; then
                WANT_SDDM=1
            else
                WANT_SDDM=0
            fi
        fi
    fi
    if [ "$WANT_SDDM" -eq 0 ]; then
        warn "TDM restera' attivo: Labwc potrebbe non comparire nel login. Usa 'dbus-run-session labwc' da TTY o reinstalla con --sddm."
    fi
else
    WANT_SDDM=0
fi

if [ -z "$THEME" ]; then
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -r /dev/tty ]; then
        THEME="nordic-cobalt"
    else
        default_choice="1"
        case "$THEME" in
            muted-crimson) default_choice="2" ;;
            sage-emerald) default_choice="3" ;;
        esac
        note "Scegli il tema iniziale: blu Nordic Cobalt, rosso Muted Crimson o verde Sage Emerald."
        choice="$(ask_choice "Tema iniziale (1=blu, 2=rosso tenue, 3=verde salvia)" "$default_choice" 1 2 3)"
        case "$choice" in
            1) THEME="nordic-cobalt" ;;
            2) THEME="muted-crimson" ;;
            3) THEME="sage-emerald" ;;
        esac
    fi
fi

chromium_installed=0
firefox_installed=0
if have chromium || have chromium-browser; then chromium_installed=1; fi
if have firefox-esr; then firefox_installed=1; fi

if [ -z "$WANT_BROWSER" ]; then
    if [ "$QUICK_UPDATE" = "1" ]; then
        WANT_BROWSER=none
    elif [ "$ASSUME_YES" -eq 1 ]; then
        WANT_BROWSER=chromium
    else
        default_choice=1
        if [ "$chromium_installed" -eq 0 ] && [ "$firefox_installed" -eq 1 ]; then
            default_choice=2
        fi
        printf '\n%sBrowser:%s\n' "$C_BOLD" "$C_RESET"
        printf '  1) Chromium — motore di Chrome: massima compatibilità con le web app\n'
        printf '     e Chrome Web Store. Usa più RAM: scegli questo se le web app\n'
        printf '     devono funzionare senza sorprese.\n'
        printf '  2) Firefox ESR — Firefox stabile e leggero: più privacy, estensioni\n'
        printf '     Mozilla e meno RAM di Chromium. Consigliato su PC datati.\n'
        printf '  3) Entrambi — Chromium e Firefox ESR, ognuno con le sue estensioni.\n'
        printf '  4) Nessuno — non installare e non modificare nessun browser.\n'
        choice="$(ask_choice "Browser (1=Chromium, 2=Firefox ESR, 3=Entrambi, 4=Nessuno)" "$default_choice" 1 2 3 4)"
        case "$choice" in
            1) WANT_BROWSER=chromium ;;
            2) WANT_BROWSER=firefox ;;
            3) WANT_BROWSER=both ;;
            4) WANT_BROWSER=none ;;
        esac
    fi
fi

# Se si sceglie un browser e l'altro e' gia' installato, chiedi se rimuoverlo.
if [ "$ASSUME_YES" -eq 0 ] && [ "$GUI_CHOICES" -eq 0 ] && [ "$WANT_BROWSER" != "both" ]; then
    if [ "$WANT_BROWSER" = "chromium" ] && [ "$firefox_installed" -eq 1 ]; then
        note "Hai scelto Chromium. Firefox ESR è già installato: puoi tenerlo o rimuoverlo."
        if ask_yes_no "Firefox ESR e' gia' installato. Vuoi disinstallarlo per usare solo Chromium?" no; then
            REMOVE_BROWSER=firefox
        fi
    elif [ "$WANT_BROWSER" = "firefox" ] && [ "$chromium_installed" -eq 1 ]; then
        note "Hai scelto Firefox ESR. Chromium è già installato: puoi tenerlo o rimuoverlo."
        if ask_yes_no "Chromium e' gia' installato. Vuoi disinstallarlo per usare solo Firefox ESR?" no; then
            REMOVE_BROWSER=chromium
        fi
    fi
fi

# qpdfview: lettore PDF leggero, utile sui PC vecchi. Non viene reinstallato.
if [ -z "$WANT_QPDFVIEW" ]; then
    if have qpdfview; then
        WANT_QPDFVIEW=0
        info "qpdfview gia' installato: nessuna reinstallazione."
    elif [ "$SKIP_APT" -eq 1 ]; then
        WANT_QPDFVIEW=0
    elif [ "$QUICK_UPDATE" = "1" ]; then
        # Le vecchie opzioni salvate non hanno QPDFVIEW: non aggiungere nulla.
        WANT_QPDFVIEW=0
    elif [ "$ASSUME_YES" -eq 1 ]; then
        WANT_QPDFVIEW=1
    else
        note "qpdfview apre i PDF senza browser ed è leggero sui PC vecchi."
        if ask_yes_no "Installare anche qpdfview, lettore PDF leggero?" yes; then
            WANT_QPDFVIEW=1
        else
            WANT_QPDFVIEW=0
        fi
    fi
fi


log "Scelte acquisite. Richiesta privilegi sudo (solo per apt e file di sistema)..."
sudo -v || die "Impossibile ottenere sudo."
# rinnova il timestamp sudo durante l'installazione
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
trap 'err_trap $LINENO' ERR

printf '\n%sRiepilogo:%s tema %s, shell %s, zram %s, swappiness %s, touchscreen %s, browser %s, qpdfview %s, FreeTube %s\n\n' \
    "$C_BOLD" "$C_RESET" "$(theme_label "$THEME")" \
    "$([ "$WANT_SHELL" = "noctalia" ] && echo "Noctalia v5" || echo "Waybar + Fuzzel")" \
    "$([ "$ENABLE_ZRAM" -eq 1 ] && echo attivo || echo no)" \
    "$([ "$ENABLE_SWAPPINESS" -eq 1 ] && echo "${SWAPPINESS_VALUE:-auto}" || echo invariato)" \
    "$([ "$ENABLE_TOUCH" -eq 1 ] && echo si || echo no)" \
    "$(browser_label "$WANT_BROWSER")" \
    "$([ "$WANT_QPDFVIEW" -eq 1 ] && echo si || echo no)" \
    "$([ "$WANT_FREETUBE" -eq 1 ] && echo si || echo no)"

# -----------------------------------------------------------------------------
# Installazione pacchetti
# -----------------------------------------------------------------------------
CORE_PKGS=(
    labwc
    waybar
    fuzzel
    swaybg
    mako-notifier
    wl-clipboard
    wtype
    grim
    slurp
    swaylock
    wlogout
    lxpolkit
    network-manager-gnome
    pavucontrol
    pulseaudio-utils
    brightnessctl
    foot
    foot-terminfo
    terminator
    pcmanfm
    btop
    wlrctl
    cage
    gvfs
    xwayland
    xauth
    xdg-desktop-portal
    curl
    python3-pil
    python3-gi
    python3-gi-cairo
    python3-websockets
    gsettings-desktop-schemas
    libglib2.0-bin
    dconf-gsettings-backend
    gir1.2-gtk-3.0
    libgtk-3-bin
    qml6-module-qtquick
    qml6-module-qtquick-controls
    qml6-module-qtquick-layouts
    qml6-module-qtquick-window
    qml-module-qtquick2
    qml-module-qtquick-controls2
    qml-module-qtquick-layouts
    qml-module-qtquick-window2
    pkexec
    zram-tools
    fonts-font-awesome
    fonts-jetbrains-mono
    fonts-inter
    fonts-noto-core
    fonts-noto-color-emoji
    adwaita-icon-theme
    hicolor-icon-theme
    librsvg2-common
    xdg-desktop-portal-wlr
    xdg-user-dirs
    xdg-utils
    zenity
    libnotify-bin
    jq
    cliphist
)
OPTIONAL_PKGS=(
    qtwayland5
    qt6-wayland
    xdg-desktop-portal-gtk
    gvfs-backends
    dbus-x11
    playerctl
    upower
    swayidle
    wlr-randr
    wdisplays
    kanshi
    mousepad
    imagemagick
    mesa-utils
)
TOUCH_PKGS=(
    wvkbd
    lisgd
    libinput-tools
    python3-evdev
    wlr-randr
)

install_packages() {
    local -a available=()
    local pkg
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            available+=("$pkg")
        else
            warn "Pacchetto non disponibile nei repository: $pkg"
        fi
    done
    [ "${#available[@]}" -gt 0 ] || return 0

    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        "${available[@]}"; then
        warn "Installazione collettiva fallita: riprovo un pacchetto alla volta."
        for pkg in "${available[@]}"; do
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
                --no-install-recommends \
                -o Dpkg::Options::=--force-confdef \
                -o Dpkg::Options::=--force-confold \
                "$pkg" || warn "Pacchetto saltato: $pkg"
        done
    fi
}

# Noctalia v5: shell integrata dal repository APT ufficiale del progetto
# (terze parti), solo Debian trixie su amd64/arm64.
# https://docs.noctalia.dev/noctalia/getting-started/installation/
install_noctalia() {
    local arch tmp
    local expected_keyring="2f58e934a5983b41dbd0d9e30fbf246f7eaef1d0c02132cf1d6f69cb87c1074f"
    local expected_sources="0400b8783090fede580d5173978440aeea7b7c443819a29d240da9851910367d"
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64|aarch64|arm64) ;;
        *)
            warn "Noctalia supporta solo amd64/arm64 (architettura rilevata: $arch)."
            return 1
            ;;
    esac

    if [ -f /etc/apt/sources.list.d/noctalia-trixie.sources ] &&
        dpkg -s nickh-archive-keyring >/dev/null 2>&1; then
        info "Repository Noctalia gia' configurato: keyring e sources invariati."
        if ! apt-cache show noctalia >/dev/null 2>&1; then
            sudo apt-get update || { warn "apt-get update non riuscito (repository Noctalia)."; return 1; }
        fi
    else
        log "Noctalia: aggiunta del repository APT di terze parti pkg.noctalia.dev..."
        tmp="$(mktemp -d)"
        if ! curl -fL --connect-timeout 10 --max-time 60 -o "$tmp/nickh-archive-keyring.deb" \
                https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb ||
            ! curl -fL --connect-timeout 10 --max-time 60 -o "$tmp/noctalia-trixie.sources" \
                https://pkg.noctalia.dev/deb/noctalia-trixie.sources; then
            rm -rf "$tmp"
            warn "Repository Noctalia: download di keyring/sources non riuscito."
            return 1
        fi
        if ! printf '%s  %s\n%s  %s\n' \
                "$expected_keyring" "$tmp/nickh-archive-keyring.deb" \
                "$expected_sources" "$tmp/noctalia-trixie.sources" |
            sha256sum -c --strict --quiet -; then
            rm -rf "$tmp"
            warn "Repository Noctalia: checksum di keyring/sources non valido. Installazione annullata."
            return 1
        fi
        if ! sudo dpkg -i "$tmp/nickh-archive-keyring.deb" ||
            ! sudo install -m 0644 "$tmp/noctalia-trixie.sources" \
                /etc/apt/sources.list.d/noctalia-trixie.sources; then
            rm -rf "$tmp"
            warn "Repository Noctalia: installazione di keyring/sources non riuscita."
            return 1
        fi
        rm -rf "$tmp"
        if ! sudo apt-get update; then
            warn "apt-get update non riuscito dopo l'aggiunta del repository Noctalia."
            sudo rm -f /etc/apt/sources.list.d/noctalia-trixie.sources
            return 1
        fi
    fi

    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends noctalia; then
        warn "Pacchetto noctalia non installato."
        return 1
    fi
    have noctalia || { warn "Comando noctalia non trovato dopo l'installazione."; return 1; }
    # VM senza adattatore Bluetooth: BlueZ non parte e ogni avvio di Noctalia
    # aspetta 25 s il D-Bus. Mascherare il servizio fa fallire subito.
    if [ -z "$(ls -A /sys/class/bluetooth 2>/dev/null || true)" ]; then
        sudo systemctl mask bluetooth.service >/dev/null 2>&1 &&
            ok "Nessun adattatore Bluetooth: servizio mascherato (avvio rapido)."
    else
        sudo systemctl unmask bluetooth.service >/dev/null 2>&1 || true
    fi
    ok "Noctalia v5 installato (repository di terze parti pkg.noctalia.dev)."
}

install_browser_extensions() {
    local policy_dir="/etc/chromium/policies/managed"
    local policy_file="$policy_dir/labwc-q4os-extensions.json"

    if ! have chromium && ! have chromium-browser; then
        warn "Chromium non installato: estensioni non configurate."
        return 0
    fi

    if [ -r "$policy_file" ] &&
        grep -q 'ddkjiahejlhfcafbddmgiahcphecmpfh' "$policy_file" &&
        grep -q 'pkehgijcmpdhfbdbbnkijodmdjhbjlgp' "$policy_file" &&
        grep -q 'omkfmpieigblcllmkgbflkikinpkodlk' "$policy_file" &&
        grep -q 'ManagedBookmarks' "$policy_file" &&
        grep -q 'youtube.it/' "$policy_file"; then
        info "Chromium: estensioni e preferito YouTube gia' configurati: nessuna modifica."
        return 0
    fi

    mkdir -p "$BACKUP_DIR/system"
    if [ -r "$policy_file" ]; then
        # shellcheck disable=SC2024
        sudo cat "$policy_file" > "$BACKUP_DIR/system/labwc-q4os-extensions.json" 2>/dev/null || true
    fi
    sudo install -d -m 0755 "$policy_dir"
    # Policy Chromium: force_installed scarica le estensioni dal Chrome Web Store
    # al primo avvio. ddkjiahejlhfcafbddmgiahcphecmpfh = uBlock Origin Lite,
    # pkehgijcmpdhfbdbbnkijodmdjhbjlgp = Privacy Badger,
    # omkfmpieigblcllmkgbflkikinpkodlk = enhanced-h264ify.
    # enhanced-h264ify blocca AV1 e VP9 di default: YouTube serve H.264 (avc1),
    # decodificabile in hardware anche su GPU vecchie. I 60fps restano attivi.
    sudo tee "$policy_file" >/dev/null <<'EOF'
{
  "BookmarkBarEnabled": true,
  "ManagedBookmarks": [
    { "toplevel_name": "labwc-q4os" },
    { "name": "YouTube 360p", "url": "https://youtube.it/" }
  ],
  "ExtensionSettings": {
    "ddkjiahejlhfcafbddmgiahcphecmpfh": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "pkehgijcmpdhfbdbbnkijodmdjhbjlgp": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "omkfmpieigblcllmkgbflkikinpkodlk": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  }
}
EOF
    sudo chmod 0644 "$policy_file"
    ok "Chromium: uBlock Origin Lite, Privacy Badger ed enhanced-h264ify installate da policy al primo avvio."
}

install_chromium_runtime() {
    local flags_file="/etc/chromium.d/zz-labwc-q4os"
    local ext_dir="/usr/share/labwc-q4os/chromium/youtube-360"

    sudo install -d -m 0755 "$ext_dir"
    sudo install -m 0644 "$REPO_DIR/configs/chromium/youtube-360/manifest.json" "$ext_dir/manifest.json"
    sudo install -m 0644 "$REPO_DIR/configs/chromium/youtube-360/content.js" "$ext_dir/content.js"
    sudo install -m 0644 "$REPO_DIR/configs/chromium/youtube-360/page.js" "$ext_dir/page.js"

    mkdir -p "$BACKUP_DIR/system"
    if [ -r "$flags_file" ]; then
        sudo cat "$flags_file" >"$BACKUP_DIR/system/zz-labwc-q4os-chromium" 2>/dev/null || true
    fi
    sudo install -d -m 0755 /etc/chromium.d
    # Wayland + decorazioni server quando disponibili. L'estensione locale
    # imposta YouTube a 360p: meno CPU, meno RAM e decodifica più facile.
    sudo tee "$flags_file" >/dev/null <<EOF
# labwc-q4os: Wayland e YouTube 360p
export CHROMIUM_FLAGS="\$CHROMIUM_FLAGS --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --load-extension=$ext_dir"
EOF
    sudo chmod 0644 "$flags_file"
    ok "Chromium: Wayland, decorazioni e YouTube 360p configurati."
}

install_cage_helper() {
    if [ "$SKIP_APT" -eq 0 ]; then
        install_packages cage
    fi
    if ! command -v cage >/dev/null 2>&1; then
        return 0
    fi
    # Cage legge /dev/input direttamente: senza gruppo input non vede
    # mouse e tastiera, anche se il wrapper di sessione e' corretto.
    local user_name="${USER:-$(id -un)}"
    if ! id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx input; then
        if sudo usermod -aG input "$user_name"; then
            info "Utente aggiunto al gruppo input: Cage funziona dal prossimo login."
        else
            warn "Impossibile aggiungere $user_name al gruppo input: Cage non ricevera' mouse e tastiera."
        fi
    fi
    if [ "$SKIP_APT" -eq 1 ]; then
        return 0
    fi
    # /usr/local/bin precede /usr/bin: la console mostra le istruzioni.
    sudo install -m 0755 "$REPO_DIR/scripts/cage-with-help" /usr/local/bin/cage
}

install_audio_keys() {
    local keyd_conf="/etc/keyd/default.conf"
    local helper="/usr/local/bin/labwc-audio-key"

    if [ "$SKIP_APT" -eq 1 ]; then
        warn "Tasti volume non configurati con --skip-apt."
        return 1
    fi
    install_packages keyd
    if ! command -v keyd >/dev/null 2>&1 && ! command -v keyd.rvaiya >/dev/null 2>&1; then
        warn "keyd non disponibile: tasti volume non mappati."
        return 1
    fi

    sudo install -d -m 0755 /etc/keyd
    if [ -r "$keyd_conf" ] && ! grep -q 'labwc-q4os' "$keyd_conf"; then
        mkdir -p "$BACKUP_DIR/system"
        sudo cat "$keyd_conf" >"$BACKUP_DIR/system/keyd-default.conf" 2>/dev/null || true
        warn "keyd: config personale salvata; non la sovrascrivo."
    elif [ ! -r "$keyd_conf" ]; then
        sudo tee "$keyd_conf" >/dev/null <<'EOF'
# labwc-q4os: tasti volume, anche dentro Cage
[ids]
*

[main]
volumeup = command(/usr/local/bin/labwc-audio-key up)
volumedown = command(/usr/local/bin/labwc-audio-key down)
mute = command(/usr/local/bin/labwc-audio-key mute)
EOF
        sudo chmod 0644 "$keyd_conf"
    fi

    sudo install -m 0755 "$REPO_DIR/scripts/labwc-audio-key" "$helper"
    sudo systemctl enable keyd >/dev/null 2>&1 || true
    sudo systemctl restart keyd >/dev/null 2>&1 || warn "keyd non riavviato."
    ok "Tasti volume mappati con keyd (anche in Cage)."
}

remove_flatpak() {
    # Scelta esplicita dell'utente: niente Flatpak/Flathub sul sistema.
    if command -v flatpak >/dev/null 2>&1; then
        sudo flatpak uninstall --all -y >/dev/null 2>&1 || true
        sudo flatpak remote-delete --system flathub >/dev/null 2>&1 || true
        sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y flatpak >/dev/null 2>&1 || true
    fi
    sudo rm -rf /var/lib/flatpak /etc/flatpak 2>/dev/null || true
    rm -rf "$HOME/.local/share/flatpak" "$HOME/.var/app/io.freetubeapp.FreeTube" 2>/dev/null || true
}

install_freetube() {
    local key_url="https://ghaaapt.github.io/freetube-apt/freetube-archive-keyring.asc"
    local keyring="/usr/share/keyrings/freetube-archive-keyring.gpg"
    local sources="/etc/apt/sources.list.d/freetube.sources"
    local tmp_key
    local free_kb

    if [ "$SKIP_APT" -eq 1 ]; then
        warn "FreeTube non installato con --skip-apt."
        return 1
    fi
    free_kb="$(df -Pk / 2>/dev/null | awk 'NR == 2 { print $4 }')"
    if [ -n "$free_kb" ] && [ "$free_kb" -lt 250000 ]; then
        warn "Spazio insufficiente per FreeTube: servono circa 250 MB liberi, trovati $((free_kb / 1024)) MB."
        return 1
    fi

    log "Configurazione repository APT FreeTube (GHaaAPT)..."
    if [ ! -r "$keyring" ]; then
        tmp_key="$(mktemp --suffix=.asc)"
        if ! curl -fsSL --proto '=https' --proto-redir '=https' --max-time 60 \
            -o "$tmp_key" "$key_url"; then
            rm -f "$tmp_key"
            warn "Chiave repo FreeTube non scaricata."
            return 1
        fi
        if ! gpg --dearmor <"$tmp_key" | sudo tee "$keyring" >/dev/null; then
            rm -f "$tmp_key"
            warn "Chiave repo FreeTube non importata."
            return 1
        fi
        sudo chmod 0644 "$keyring"
        rm -f "$tmp_key"
    fi
    sudo install -d -m 0755 /etc/apt/sources.list.d
    sudo tee "$sources" >/dev/null <<'EOF'
Types: deb
URIs: https://ghaaapt.github.io/freetube-apt/
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/freetube-archive-keyring.gpg
EOF
    sudo chmod 0644 "$sources"
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq ||
        warn "apt update dopo il repo FreeTube ha segnalato errori: proseguo."

    if ! apt-cache show freetube >/dev/null 2>&1; then
        warn "Pacchetto FreeTube non disponibile nel repo appena aggiunto."
        return 1
    fi

    # FreeTube 0.24+ usa SABR in modo obbligatorio: su molte reti/versioni
    # entra nel loop "reloading player according to SABR request".
    # 0.23.15 e' l'ultima senza SABR e riproduce i video con i vecchi flussi.
    local pin_version="0.23.15"
    local pin_sha="2b773bba2d9f58daa78fd259de725daa8331405816b542434e9a912294dd4b89"
    local pin_url=""
    local tmp_deb=""
    if [ "${FREETUBE_PIN:-$pin_version}" = "latest" ]; then
        sudo apt-mark unhold freetube >/dev/null 2>&1 || true
        log "Installazione FreeTube dal repository APT (circa 100 MB)..."
        if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y freetube; then
            warn "Installazione FreeTube dal repository non riuscita."
            return 1
        fi
        ok "FreeTube installato dal repo APT (aggiornamenti con apt)."
        return 0
    fi

    case "$(dpkg --print-architecture)" in
        amd64)
            pin_url="https://github.com/FreeTubeApp/FreeTube/releases/download/v${pin_version}-beta/freetube_${pin_version}_beta_amd64.deb"
            ;;
        *)
            warn "FreeTube ${pin_version} pinnato solo su amd64: uso l'ultima versione (puo' avere il bug SABR)."
            sudo apt-mark unhold freetube >/dev/null 2>&1 || true
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y freetube || return 1
            return 0
            ;;
    esac

    log "Installazione FreeTube ${pin_version} (senza SABR)..."
    tmp_deb="$(mktemp --suffix=.deb)"
    if ! curl -fL --proto '=https' --proto-redir '=https' --retry 2 \
        --max-time 300 -o "$tmp_deb" "$pin_url"; then
        rm -f "$tmp_deb"
        warn "Download FreeTube ${pin_version} non riuscito: installo l'ultima versione."
        sudo apt-mark unhold freetube >/dev/null 2>&1 || true
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y freetube || return 1
        return 0
    fi
    if ! echo "${pin_sha}  ${tmp_deb}" | sha256sum -c - >/dev/null 2>&1; then
        rm -f "$tmp_deb"
        warn "Checksum FreeTube ${pin_version} non valido: installo l'ultima versione."
        sudo apt-mark unhold freetube >/dev/null 2>&1 || true
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y freetube || return 1
        return 0
    fi
    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --allow-downgrades "$tmp_deb"; then
        rm -f "$tmp_deb"
        warn "Installazione FreeTube ${pin_version} non riuscita."
        return 1
    fi
    rm -f "$tmp_deb"
    sudo apt-mark hold freetube >/dev/null 2>&1 || true
    ok "FreeTube ${pin_version} installato e bloccato (niente SABR; apt non lo aggiorna)."
    info "Per tornare all'ultima versione: sudo apt-mark unhold freetube && FREETUBE_PIN=latest ./install.sh"
}

configure_freetube() {
    local dir="$CONFIG/FreeTube"
    local db="$dir/settings.db"

    if pgrep -x freetube >/dev/null 2>&1; then
        warn "FreeTube e' aperto: chiudilo e rilancia l'installer per applicare i 360p."
        return 1
    fi
    mkdir -p "$dir"
    chmod 0700 "$dir" 2>/dev/null || true
    if python3 - "$db" <<'PY'
import json
import os
import sys

path = sys.argv[1]
docs = []
if os.path.exists(path):
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                doc = json.loads(line)
            except ValueError:
                continue
            if isinstance(doc, dict) and "_id" in doc:
                docs.append(doc)

docs = [doc for doc in docs
        if doc.get("_id") not in ("defaultQuality", "checkForUpdates")]
docs.append({"_id": "defaultQuality", "value": "360"})
docs.append({"_id": "checkForUpdates", "value": False})
# Una sola voce per _id (NeDB compatta cosi' al prossimo avvio).
docs = list({doc["_id"]: doc for doc in docs}.values())

tmp = path + ".labwc-q4os.tmp"
with open(tmp, "w", encoding="utf-8") as handle:
    for doc in docs:
        handle.write(json.dumps(doc, separators=(",", ":"), ensure_ascii=False))
        handle.write("\n")
os.chmod(tmp, 0o600)
os.replace(tmp, path)
PY
    then
        ok "FreeTube: qualita' 360p, controllo aggiornamenti disattivato."
    else
        warn "Impossibile configurare FreeTube (360p/aggiornamenti)."
    fi
}

install_firefox_extensions() {
    # Questa build di Firefox ESR applica la policy distribuita dal pacchetto;
    # /etc/firefox-esr/policies ha priorità sulla policy del pacchetto; si aggiorna anche
    # /usr/share. Un aggiornamento del pacchetto lo sostituisce e l'installer
    # lo ripristina alla successiva esecuzione.
    local policy_file="/etc/firefox-esr/policies/policies.json"
    local policy_dir
    policy_dir="$(dirname "$policy_file")"
    local dist_policy="/usr/share/firefox-esr/distribution/policies.json"
    local ext_dir="/usr/share/firefox-esr/distribution/extensions"
    local xpi="$ext_dir/{9a41dee2-b924-4161-a971-7fb35c053a4a}.xpi"

    if ! have firefox-esr; then
        warn "Firefox ESR non installato: estensioni non configurate."
        return 0
    fi
    local ff_xpi="$ext_dir/youtube-360@labwc-q4os.xpi"
    if [ -r "$policy_file" ] && [ -r "$xpi" ] && [ -r "$ff_xpi" ] &&
        grep -q 'uBlock0@raymondhill.net' "$policy_file" &&
        grep -q 'jid1-MnnxcxisBPnSXQ@jetpack' "$policy_file" &&
        grep -q '9a41dee2-b924-4161-a971-7fb35c053a4a' "$policy_file" &&
        grep -q 'youtube.it/' "$policy_file"; then
        info "Firefox ESR: estensioni e preferito YouTube gia' configurati: nessuna modifica."
        return 0
    fi

    mkdir -p "$BACKUP_DIR/system"
    if [ -r "$policy_file" ]; then
        sudo cat "$policy_file" >"$BACKUP_DIR/system/firefox-esr-distribution-policies.json" 2>/dev/null || true
    fi
    sudo install -d -m 0755 "$policy_dir"
    # /etc ha priorita' sulla policy del pacchetto: parti da quella del
    # pacchetto per non perdere le protezioni predefinite di Firefox ESR.
    sudo python3 - "$dist_policy" "$policy_file" <<'PY'
import json
import os
import sys
import tempfile

dist, dst = sys.argv[1], sys.argv[2]
data = None
for path in (dst, dist, "/usr/lib/firefox-esr/distribution/policies.json"):
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        break
    except (OSError, ValueError):
        continue
if data is None:
    data = {}
policies = data.setdefault("policies", {})
prefs = policies.setdefault("Preferences", {})
prefs["xpinstall.signatures.required"] = {"Value": False, "Status": "default"}
prefs["dom.ipc.processCount"] = {"Value": 2, "Status": "default"}
prefs["browser.tabs.unloadOnLowMemory"] = {"Value": True, "Status": "default"}
policies["DisplayBookmarksToolbar"] = True
bookmark_url = "https://youtube.it/"
bookmarks = policies.setdefault("Bookmarks", [])
if not any(item.get("URL") == bookmark_url for item in bookmarks if isinstance(item, dict)):
    bookmarks.append({
        "Title": "YouTube 360p",
        "URL": bookmark_url,
        "Placement": "toolbar",
        "Folder": "labwc-q4os",
    })
extensions = policies.setdefault("ExtensionSettings", {})
for ext_id, url in {
    "uBlock0@raymondhill.net":
        "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
    "jid1-MnnxcxisBPnSXQ@jetpack":
        "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi",
    "9a41dee2-b924-4161-a971-7fb35c053a4a":
        "https://addons.mozilla.org/firefox/downloads/latest/enhanced-h264ify/latest.xpi",
}.items():
    extensions[ext_id] = {
        "installation_mode": "force_installed",
        "install_url": url,
        "private_browsing": True,
        "default_area": "navbar",
    }
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(dst), prefix=".policies.")
with os.fdopen(fd, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
os.chmod(tmp, 0o644)
os.replace(tmp, dst)
PY
    sudo chmod 0644 "$policy_file"
    if [ -d "$(dirname "$dist_policy")" ]; then
        sudo install -m 0644 "$policy_file" "$dist_policy"
    fi

    # enhanced-h264ify da policy non viene installata da questa build di
    # Firefox ESR; il file in distribution/extensions invece viene caricato.
    local tmp_xpi
    sudo install -d -m 0755 "$ext_dir"
    tmp_xpi="$(mktemp)"
    if curl -fsSL --proto '=https' --proto-redir '=https' --max-time 60 \
        "https://addons.mozilla.org/firefox/downloads/latest/enhanced-h264ify/latest.xpi" \
        -o "$tmp_xpi"; then
        sudo install -m 0644 "$tmp_xpi" "$xpi"
    else
        warn "enhanced-h264ify non scaricata: riprova con l'aggiornamento."
    fi
    rm -f "$tmp_xpi"
    # Estensione locale 360p per Firefox ESR: la build installata non accetta
    # XPI non firmati via policy, quindi usiamo distribution/extensions.
    local ff_src="$REPO_DIR/configs/firefox/youtube-360"
    local ff_tmp
    ff_tmp="$(mktemp --suffix=.xpi)"
    python3 - "$ff_src" "$ff_tmp" <<'PY'
import os
import sys
import zipfile

src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in ("manifest.json", "content.js", "page.js"):
        archive.write(os.path.join(src, name), name)
PY
    sudo install -m 0644 "$ff_tmp" "$ff_xpi"
    rm -f "$ff_tmp"
    ok "Firefox ESR: estensioni e YouTube 360p installate."
}

install_firefox() {
    if [ "$SKIP_APT" -eq 1 ]; then
        if have firefox-esr; then
            info "Firefox ESR gia' installato; nessuna modifica (--skip-apt)."
            return 0
        fi
        warn "Firefox ESR non installato e --skip-apt attivo."
        return 1
    fi

    if have firefox-esr; then
        info "Firefox ESR gia' installato: aggiornamenti dal repository Debian."
        return 0
    fi
    log "Installazione Firefox ESR dal repository Debian..."
    install_packages firefox-esr
    have firefox-esr
}

remove_browser() {
    local browser="$1"
    local -a packages=()
    local pkg
    case "$browser" in
        chromium) packages=(chromium chromium-browser) ;;
        firefox) packages=(firefox-esr) ;;
        librewolf) packages=(librewolf) ;;
        *) return 0 ;;
    esac
    local -a installed=()
    for pkg in "${packages[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            installed+=("$pkg")
        fi
    done
    [ "${#installed[@]}" -gt 0 ] || return 0
    log "Disinstallazione di ${installed[*]}..."
    if sudo env DEBIAN_FRONTEND=noninteractive apt-get remove -y "${installed[@]}"; then
        rm -f "$APPDATA/$browser.desktop" "$APPDATA/$browser-cage.desktop"
        ok "Disinstallato: ${installed[*]}"
    else
        warn "Disinstallazione non riuscita: ${installed[*]}"
    fi
}

# Rimuove i pacchetti dell'altra shell, se presenti. Usata dopo aver scelto
# e verificato la shell: Noctalia toglie Waybar/Mako/swaybg/Fuzzel; Waybar
# toglie Noctalia. Non interrompe l'installazione se apt fallisce.
remove_shell_packages() {
    local -a to_remove=()
    local pkg
    for pkg in "$@"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            to_remove+=("$pkg")
        fi
    done
    [ "${#to_remove[@]}" -gt 0 ] || return 0
    log "Rimozione della shell non scelta: ${to_remove[*]}"
    if sudo env DEBIAN_FRONTEND=noninteractive apt-get remove -y "${to_remove[@]}"; then
        ok "Rimossi: ${to_remove[*]}"
    else
        warn "Rimozione non riuscita: ${to_remove[*]}. Restano installati ma non verranno avviati."
    fi
}

if [ "$SKIP_APT" -eq 1 ]; then
    warn "Installazione pacchetti saltata (--skip-apt)."
    if [ "$WANT_LOOKSWITCHER" -eq 1 ]; then
        warn "LookSwitcher non installato con --skip-apt."
        WANT_LOOKSWITCHER=0
    fi
else
    log "Aggiornamento elenco pacchetti..."
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq || warn "apt-get update ha segnalato errori: proseguo."

    if ! apt-cache show labwc >/dev/null 2>&1; then
        die "labwc non e' disponibile nei repository di questa release.
Q4OS 6.x (Debian 13) include labwc; Q4OS 5.x / Debian 12 no.
Aggiorna a Q4OS 6 oppure usa una release Debian 13 o successiva."
    fi

    log "Installazione pacchetti base (puo' richiedere qualche minuto)..."
    if [ "$WANT_SHELL" = "noctalia" ]; then
        # Una sola shell: con Noctalia non installiamo Waybar/Mako.
        # swaybg resta come sfondo immediato finché Noctalia non è pronto.
        # Fuzzel resta per gli strumenti del progetto (menu, temi), non come launcher.
        shell_core=()
        for pkg in "${CORE_PKGS[@]}"; do
            case "$pkg" in
                waybar|mako-notifier|fuzzel) continue ;;
            esac
            shell_core+=("$pkg")
        done
        install_packages "${shell_core[@]}"
    else
        install_packages "${CORE_PKGS[@]}"
    fi
    log "Installazione pacchetti opzionali consigliati..."
    install_packages "${OPTIONAL_PKGS[@]}"
    remove_flatpak || true
    install_audio_keys || true
    install_cage_helper || true

    if [ "$ENABLE_TOUCH" -eq 1 ]; then
        log "Installazione componenti touchscreen (wvkbd, lisgd, libinput-tools)..."
        install_packages "${TOUCH_PKGS[@]}"
    fi

    if [ "$ENABLE_ZRAM" -eq 1 ]; then
        if apt-cache show zram-tools >/dev/null 2>&1; then
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends zram-tools ||
                warn "zram-tools non installato."
        else
            warn "zram-tools non disponibile: zram non verra' configurato."
        fi
    fi

    if [ "$WANT_SDDM" -eq 1 ]; then
        if apt-cache show sddm >/dev/null 2>&1; then
            log "Installazione di SDDM per il supporto Wayland nel login..."
            install_packages sddm
        else
            warn "sddm non disponibile nei repository: TDM resta attivo."
            WANT_SDDM=0
        fi
    fi

    if [ "$WANT_LOOKSWITCHER" -eq 1 ] && [ "$trinity_present" -eq 1 ]; then
        lsw_pkg=""
        for candidate in lookswitcher-trinity lookswitcher; do
            if apt-cache show "$candidate" >/dev/null 2>&1; then
                lsw_pkg="$candidate"
                break
            fi
        done
        if [ -n "$lsw_pkg" ]; then
            log "Installazione LookSwitcher per Trinity ($lsw_pkg)..."
            if sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
                --no-install-recommends "$lsw_pkg"; then
                ok "LookSwitcher installato: selettore temi disponibile in Trinity."
            else
                warn "LookSwitcher non installato: Trinity resta senza selettore temi."
                WANT_LOOKSWITCHER=0
            fi
        else
            warn "LookSwitcher non disponibile nei repository Q4OS: nessuna modifica."
            WANT_LOOKSWITCHER=0
        fi
    fi
fi

# Noctalia solo se scelta e installabile: in ogni caso di fallimento si resta
# su Waybar + Fuzzel, senza interrompere l'installazione.
if [ "$WANT_SHELL" = "noctalia" ]; then
    shell_ok=1
    if [ "$SKIP_APT" -eq 1 ] && ! have noctalia; then
        warn "Noctalia non installabile con --skip-apt: uso Waybar + Fuzzel."
        shell_ok=0
    elif ! have apt-get; then
        warn "Noctalia richiede apt (Debian/Q4OS): uso Waybar + Fuzzel."
        shell_ok=0
    else
        case " $OS_ID $OS_LIKE " in
            *debian*|*q4os*) ;;
            *)
                warn "Noctalia richiede Debian/Q4OS (repository APT dedicato): uso Waybar + Fuzzel."
                shell_ok=0
                ;;
        esac
    fi
    if [ "$shell_ok" -eq 1 ] && [ "$SKIP_APT" -ne 1 ] && ! install_noctalia; then
        warn "Installazione di Noctalia non riuscita: uso Waybar + Fuzzel."
        shell_ok=0
    fi
    if [ "$shell_ok" -eq 0 ]; then
        WANT_SHELL=waybar
        # Se avevamo saltato Waybar/Mako/swaybg per Noctalia, li installiamo ora.
        if [ "$SKIP_APT" -ne 1 ] && have apt-get; then
            log "Ripristino Waybar + Mako + swaybg per il fallback..."
            install_packages waybar mako-notifier swaybg
        fi
    fi
fi

# Shell esclusiva: rimuove davvero i pacchetti dell'altra shell.
if [ "$SKIP_APT" -ne 1 ] && have apt-get; then
    if [ "$WANT_SHELL" = "noctalia" ]; then
        remove_shell_packages waybar mako-notifier fuzzel
    else
        remove_shell_packages noctalia
    fi
elif [ "$WANT_SHELL" = "noctalia" ]; then
    warn "Noctalia scelto con --skip-apt: Waybar/Fuzzel non vengono rimossi (non verranno avviati)."
fi

if { [ "$WANT_BROWSER" = "chromium" ] || [ "$WANT_BROWSER" = "both" ]; }; then
    if ! have chromium && ! have chromium-browser; then
        if [ "$SKIP_APT" -eq 1 ]; then
            warn "Chromium non installato e --skip-apt attivo: estensioni non configurate."
        else
            log "Installazione Chromium (solo se mancante)..."
            install_packages chromium
        fi
    else
        info "Chromium gia' installato: non viene reinstallato."
    fi
    if have chromium || have chromium-browser; then
        log "Configurazione estensioni Chromium mancanti..."
        install_browser_extensions
        install_chromium_runtime
    else
        warn "Chromium assente: estensioni non installate."
    fi
elif { [ "$WANT_BROWSER" = "firefox" ] || [ "$WANT_BROWSER" = "both" ]; }; then
    install_firefox || true
    if have firefox-esr; then
        log "Configurazione estensioni Firefox ESR..."
        install_firefox_extensions
    else
        warn "Firefox ESR assente: estensioni non installate."
    fi
else
    info "Nessun browser scelto: nessuna installazione."
fi

# Con "both" il primo ramo ha installato Chromium: installa anche Firefox ESR
# prima di configurare estensioni e preferiti di entrambi.
if [ "$WANT_BROWSER" = "both" ]; then
    install_firefox || true
fi

# Se entrambi i browser restano installati, entrambi ricevono estensioni e
# preferito YouTube 360p; l'altro browser viene rimosso solo dopo.
if [ "$WANT_BROWSER" != "none" ] && { have chromium || have chromium-browser; }; then
    install_browser_extensions
    install_chromium_runtime
fi
if [ "$WANT_BROWSER" != "none" ] && have firefox-esr; then
    install_firefox_extensions
fi

# Migrazione da LibreWolf a Firefox ESR: rimuove le vecchie voci di menu.
# Se si sceglie Firefox ESR, disinstalla anche LibreWolf (tranne --skip-apt).
rm -f "$APPDATA/librewolf.desktop" "$APPDATA/librewolf-cage.desktop"
if [ "$WANT_BROWSER" = "firefox" ] && [ "$SKIP_APT" -ne 1 ] && have librewolf; then
    remove_browser librewolf
fi

if [ -n "$REMOVE_BROWSER" ]; then
    selected_ok=0
    case "$WANT_BROWSER" in
        chromium)
            if have chromium || have chromium-browser; then selected_ok=1; fi ;;
        firefox)
            if have firefox-esr; then selected_ok=1; fi ;;
    esac
    if [ "$selected_ok" -eq 1 ] && [ "$SKIP_APT" -ne 1 ]; then
        remove_browser "$REMOVE_BROWSER"
    else
        warn "Browser scelto non disponibile: non rimuovo $REMOVE_BROWSER."
    fi
fi

if [ "$WANT_QPDFVIEW" -eq 1 ]; then
    if have qpdfview; then
        info "qpdfview gia' installato: non viene reinstallato."
    elif [ "$SKIP_APT" -eq 1 ]; then
        warn "qpdfview non installato e --skip-apt attivo: nessuna modifica."
    else
        log "Installazione qpdfview (lettore PDF leggero)..."
        install_packages qpdfview
    fi
else
    info "qpdfview non richiesto: nessuna modifica."
fi

if [ "$WANT_FREETUBE" -eq 1 ]; then
    install_freetube || true
    if command -v freetube >/dev/null 2>&1; then
        configure_freetube || true
    fi
else
    info "FreeTube non richiesto: nessuna modifica."
fi


required_cmds=(labwc foot python3)
if [ "$WANT_SHELL" = "waybar" ]; then
    required_cmds+=(waybar fuzzel)
else
    required_cmds+=(noctalia)
fi
for required_cmd in "${required_cmds[@]}"; do
    if ! command -v "$required_cmd" >/dev/null 2>&1; then
        die "Comando essenziale mancante: $required_cmd. Controlla l'installazione apt."
    fi
done
python3 -c 'import PIL' >/dev/null 2>&1 || die "python3-pil mancante: impossibile generare gli sfondi."

ok "Stack Wayland installato."

# -----------------------------------------------------------------------------
# Backup configurazioni esistenti
# -----------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
backup_tree() {
    local path="$1" rel="$2"
    if [ -e "$path" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$path" "$BACKUP_DIR/$rel"
        info "Backup: $path -> $BACKUP_DIR/$rel"
    fi
}

backup_tree "$CONFIG/labwc" "config/labwc"
backup_tree "$CONFIG/waybar" "config/waybar"
backup_tree "$CONFIG/fuzzel" "config/fuzzel"
backup_tree "$CONFIG/mako" "config/mako"
backup_tree "$CONFIG/wlogout" "config/wlogout"
backup_tree "$CONFIG/gtk-3.0" "config/gtk-3.0"
backup_tree "$CONFIG/gtk-4.0" "config/gtk-4.0"
for entry in labwc-theme-switcher labwc-menu-editor labwc-help; do
    backup_tree "$APPDATA/$entry.desktop" "config/applications/$entry.desktop"
done
backup_tree "$APPDATA/labwc-zram.desktop" "config/applications/labwc-zram.desktop"
backup_tree "$APPDATA/labwc-doctor.desktop" "config/applications/labwc-doctor.desktop"
backup_tree "$APPDATA/labwc-app-manager.desktop" "config/applications/labwc-app-manager.desktop"
backup_tree "$APPDATA/labwc-update-gui.desktop" "config/applications/labwc-update-gui.desktop"
backup_tree "$APPDATA/labwc-preferences.desktop" "config/applications/labwc-preferences.desktop"
backup_tree "$APPDATA/labwc-sysinfo.desktop" "config/applications/labwc-sysinfo.desktop"

configure_keyboard() {
    local env_file="$CONFIG/labwc/environment" tmp
    mkdir -p "$CONFIG/labwc"
    tmp="$(mktemp)"
    if [ -r "$env_file" ]; then
        grep -v -E '^XKB_DEFAULT_(LAYOUT|OPTIONS)=' "$env_file" > "$tmp" || true
    fi
    printf 'XKB_DEFAULT_LAYOUT=%s\n' "$XKB_LAYOUT" >> "$tmp"
    if [ -n "$XKB_OPTIONS" ]; then
        printf 'XKB_DEFAULT_OPTIONS=%s\n' "$XKB_OPTIONS" >> "$tmp"
    fi
    install -m 0644 "$tmp" "$env_file"
    rm -f "$tmp"

    # Layout di login/console/X11: utile per TDM, SDDM e console.
    mkdir -p "$BACKUP_DIR/system"
    if [ -r /etc/default/keyboard ]; then
        # shellcheck disable=SC2024
        sudo cat /etc/default/keyboard > "$BACKUP_DIR/system/keyboard" 2>/dev/null || true
    fi
    if command -v localectl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        sudo localectl set-keyboard-layout "$XKB_PRIMARY" >/dev/null 2>&1 || true
    fi
    if [ -r /etc/default/keyboard ]; then
        if sudo grep -q '^XKBLAYOUT=' /etc/default/keyboard; then
            sudo sed -i "s|^XKBLAYOUT=.*|XKBLAYOUT=\"$XKB_PRIMARY\"|" /etc/default/keyboard
        else
            printf 'XKBLAYOUT="%s"\n' "$XKB_PRIMARY" | sudo tee -a /etc/default/keyboard >/dev/null
        fi
    fi
    # SDDM gira su X11 e legge la tastiera da xorg.conf.d: fallback se
    # localectl non ha scritto il file (garantisce IT/lingua scelta al login).
    local greeter_xkb="/etc/X11/xorg.conf.d/00-keyboard.conf"
    if [ -f "$greeter_xkb" ] && grep -q 'Identifier "system-keyboard"' "$greeter_xkb" 2>/dev/null; then
        if sudo grep -q 'Option "XkbLayout"' "$greeter_xkb"; then
            sudo sed -i "s|Option \"XkbLayout\".*|Option \"XkbLayout\" \"$XKB_PRIMARY\"|" "$greeter_xkb"
        else
            sudo tee "$greeter_xkb" >/dev/null <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$XKB_PRIMARY"
EndSection
EOF
            sudo chmod 0644 "$greeter_xkb"
        fi
    else
        sudo install -d -m 0755 /etc/X11/xorg.conf.d
        sudo tee "$greeter_xkb" >/dev/null <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$XKB_PRIMARY"
EndSection
EOF
        sudo chmod 0644 "$greeter_xkb"
        info "Tastiera del login X11/SDDM: $XKB_PRIMARY"
    fi

    ok "Layout tastiera: $XKB_LAYOUT (login/console: $XKB_PRIMARY)"
}

configure_touchscreen() {
    local env_file="$CONFIG/labwc/environment"
    local marker="$CONFIG/labwc/touchscreen.enabled"
    local user_name="${USER:-$(id -un)}"

    if [ "$ENABLE_TOUCH" -ne 1 ]; then
        rm -f "$marker"
        return 0
    fi

    printf '1\n' > "$marker"
    chmod 0644 "$marker" 2>/dev/null || true

    # Scaling leggibile e input touch nei browser. GDK_SCALE resta 1
    # (GTK accetta solo interi): per i font si usa il tema del desktop.
    sed -i '/^QT_AUTO_SCREEN_SCALE_FACTOR=/d;/^QT_SCALE_FACTOR=/d;/^GDK_SCALE=/d;/^MOZ_USE_XINPUT2=/d' "$env_file"
    {
        printf 'QT_AUTO_SCREEN_SCALE_FACTOR=0\n'
        printf 'QT_SCALE_FACTOR=1.25\n'
        printf 'GDK_SCALE=1\n'
        printf 'MOZ_USE_XINPUT2=1\n'
    } >> "$env_file"

    # lisgd legge /dev/input/event* senza root se l'utente e' nel gruppo input.
    if id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx input; then
        info "Utente gia' nel gruppo input."
    elif sudo usermod -aG input "$user_name"; then
        info "Utente aggiunto al gruppo input: i gesti partono dal prossimo login."
    else
        warn "Impossibile aggiungere $user_name al gruppo input: i gesti touch non partiranno."
    fi

    # labwc-touch-tap inietta click e Esc via /dev/uinput. Di default e'
    # root:root 0600: diamo accesso al gruppo input (gia' usato per evdev).
    sudo install -d -m 0755 /etc/udev/rules.d
    printf '%s\n' \
        '# labwc-q4os: touch tap -> click destro / Esc' \
        'KERNEL=="uinput", GROUP="input", MODE="0660"' |
        sudo tee /etc/udev/rules.d/60-labwc-q4os-uinput.rules >/dev/null
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger --name-match=uinput 2>/dev/null || true
    if [ -e /dev/uinput ]; then
        sudo chgrp input /dev/uinput 2>/dev/null || true
        sudo chmod 0660 /dev/uinput 2>/dev/null || true
    fi
    info "Touch: tap a 2 dita = destro, 3 dita = Esc (via uinput)."
}

# -----------------------------------------------------------------------------
# Installazione file condivisi
# -----------------------------------------------------------------------------
log "Installazione temi, template e script in $SHARE..."
mkdir -p "$SHARE/themes" "$SHARE/templates" "$SHARE/wallpapers" "$SHARE/scripts" "$SHARE/icons" "$BIN"
cp -a "$REPO_DIR/configs/themes/." "$SHARE/themes/"
install -m 0644 "$REPO_DIR/configs/waybar/style.css.in" "$SHARE/templates/waybar-style.css"
install -m 0644 "$REPO_DIR/configs/fuzzel/fuzzel.ini.in" "$SHARE/templates/fuzzel.ini"
install -m 0644 "$REPO_DIR/configs/mako/config.in" "$SHARE/templates/mako-config"
install -m 0644 "$REPO_DIR/configs/wlogout/style.css.in" "$SHARE/templates/wlogout-style.css"
install -m 0644 "$REPO_DIR/configs/labwc/rc.xml" "$SHARE/templates/rc.xml"
install -m 0644 "$REPO_DIR/configs/labwc/environment" "$SHARE/templates/environment"
install -m 0755 "$REPO_DIR/configs/labwc/autostart" "$SHARE/templates/autostart"
install -m 0644 "$REPO_DIR/configs/waybar/config.jsonc" "$SHARE/templates/waybar-config.jsonc"
install -m 0644 "$REPO_DIR/configs/wlogout/layout" "$SHARE/templates/wlogout-layout"
install -m 0644 "$REPO_DIR/configs/gtk/settings.ini" "$SHARE/templates/gtk-settings.ini"
install -m 0755 "$REPO_DIR/scripts/generate-wallpapers.py" "$SHARE/scripts/generate-wallpapers.py"
install -m 0755 "$REPO_DIR/scripts/generate-icons.py" "$SHARE/scripts/generate-icons.py"
install -m 0755 "$REPO_DIR/scripts/render-menu.py" "$SHARE/scripts/render-menu.py"
install -m 0755 "$REPO_DIR/scripts/labwc-theme-apply" "$SHARE/scripts/labwc-theme-apply"
install -m 0755 "$REPO_DIR/scripts/labwc-sysinfo" "$SHARE/scripts/labwc-sysinfo"
install -m 0644 "$REPO_DIR/scripts/help.txt" "$SHARE/help.txt"

log "Generazione icone SVG coordinate ai tre temi..."
python3 "$REPO_DIR/scripts/generate-icons.py" --all \
    --themes-dir "$SHARE/themes" --output "$SHARE/icons" >/dev/null
ok "Icone generate in $SHARE/icons"
install -m 0644 "$REPO_DIR/VERSION" "$SHARE/VERSION"
install -m 0644 "$REPO_DIR/CHANGELOG.md" "$SHARE/CHANGELOG.md"
printf 'version=%s\ninstalled=%s\nrepo=%s\n' \
    "$(head -n1 "$REPO_DIR/VERSION" | tr -d '[:space:]')" \
    "$(date -Iseconds)" \
    "https://github.com/reverseloop-dev/labwc-q4os" > "$SHARE/version-info"

for helper in \
    labwc-theme-apply \
    labwc-theme-switcher \
    labwc-menu-editor \
    labwc-reload \
    labwc-generate-wallpapers \
    labwc-help \
    labwc-screenshot \
    labwc-zram \
    labwc-doctor \
    labwc-app-manager \
    labwc-update-check \
    labwc-update-copy \
    labwc-update-popup \
    labwc-update-run \
    labwc-update-gui \
    labwc-preferences \
    labwc-desktop \
    labwc-desktop-state \
    labwc-desktop-status \
    labwc-desktop-menu \
    labwc-power-menu \
    labwc-sysinfo \
    labwc-touchscreen \
    labwc-touch-tap \
    labwc-login-theme \
    labwc-fuzzel-apps \
    labwc-minimized \
    labwc-install-wizard \
    labwc-cage \
    labwc-freetube \
    labwc-freetube-cage \
    freetube-close-overlay \
    labwc-cage-help \
    labwc-return \
    labwc-session-start
do
    install -m 0755 "$REPO_DIR/scripts/$helper" "$BIN/$helper"
done

# Migrazione: rimuove il vecchio YouTube leggero e gtk-pipe-viewer.
rm -f "$BIN/labwc-youtube" "$APPDATA/labwc-youtube.desktop"
sudo rm -f /usr/local/bin/gtk-pipe-viewer /usr/local/bin/pipe-viewer \
    /usr/share/applications/gtk-pipe-viewer.desktop \
    /usr/share/pixmaps/gtk-pipe-viewer.png 2>/dev/null || true
sudo rm -rf /usr/local/share/perl/*/WWW/PipeViewer* \
    /usr/local/share/man/man3/WWW::PipeViewer* 2>/dev/null || true
rm -rf "$HOME/.config/pipe-viewer"

# -----------------------------------------------------------------------------
# Configurazioni utente
# -----------------------------------------------------------------------------
log "Installazione configurazioni utente..."
mkdir -p "$CONFIG/labwc" "$CONFIG/waybar" "$CONFIG/fuzzel" "$CONFIG/mako" "$CONFIG/wlogout" \
         "$CONFIG/gtk-3.0" "$CONFIG/gtk-4.0" "$APPDATA"

# Migrazione: le vecchie versioni mettevano le voci .desktop in
# ~/.config/applications, dove Fuzzel e il menu non le leggono.
if [ -d "$CONFIG/applications" ]; then
    for old_entry in "$CONFIG"/applications/labwc-*.desktop; do
        [ -f "$old_entry" ] || continue
        install -m 0644 "$old_entry" "$APPDATA/$(basename "$old_entry")"
        rm -f "$old_entry"
    done
    rmdir "$CONFIG/applications" 2>/dev/null || true
fi

install -m 0644 "$REPO_DIR/configs/labwc/environment" "$CONFIG/labwc/environment"
configure_keyboard
configure_touchscreen

# Marker della shell scelta: letto da labwc-session-start, labwc-theme-apply
# e labwc-doctor. Senza marker il comportamento resta quello classico (waybar).
printf '%s\n' "$WANT_SHELL" > "$CONFIG/labwc/shell"
chmod 0644 "$CONFIG/labwc/shell"
if [ "$WANT_SHELL" = "noctalia" ] && [ ! -f "$CONFIG/noctalia/config.toml" ]; then
    # Palette derivata dallo sfondo, modalita' scura e cartella sfondi del
    # progetto (il picker di Noctalia altrimenti mostra solo ~/Pictures).
    mkdir -p "$CONFIG/noctalia"
    cat > "$CONFIG/noctalia/config.toml" <<EOF
# Generato da labwc-q4os — https://github.com/reverseloop-dev/labwc-q4os
[theme]
mode = "dark"
source = "wallpaper"

[wallpaper]
directory = "$SHARE/wallpapers"
fill_mode = "crop"
EOF
    chmod 0644 "$CONFIG/noctalia/config.toml"
fi
if [ "$WANT_SHELL" = "noctalia" ]; then
    # Overlay del progetto: sfondi, niente download community all'avvio
    # (su VM/rete lenta bloccavano il login per decine di secondi).
    mkdir -p "$CONFIG/noctalia"
    cat > "$CONFIG/noctalia/99-labwc-q4os.toml" <<EOF
# Generato da labwc-q4os — non modificare a mano
[wallpaper]
directory = "$SHARE/wallpapers"

[theme.templates]
enable_community_templates = false

[shell.launcher]
fetch_exchange_rates = false

[weather]
enabled = false

[shell]
offline_mode = true
EOF
    chmod 0644 "$CONFIG/noctalia/99-labwc-q4os.toml"
fi

install -m 0755 "$REPO_DIR/configs/labwc/autostart" "$CONFIG/labwc/autostart"
sed "s|@@HOME@@|$HOME|g" "$REPO_DIR/configs/labwc/rc.xml" > "$CONFIG/labwc/rc.xml.tmp"
install -m 0644 "$CONFIG/labwc/rc.xml.tmp" "$CONFIG/labwc/rc.xml"
rm -f "$CONFIG/labwc/rc.xml.tmp"
if [ "$ENABLE_TOUCH" -eq 1 ]; then
    # Font piu' grandi per il tocco (rc.xml e' appena stato riscritto dal template).
    sed -i 's|<size>10</size>|<size>13</size>|g' "$CONFIG/labwc/rc.xml"
fi
if [ "$WANT_SHELL" = "noctalia" ]; then
    # Launcher Noctalia su tutti i tasti che prima aprivano Fuzzel.
    for launcher_key in W-d A-F2 W-space; do
        sed -i "/<keybind key=\"$launcher_key\">/,/<\\/keybind>/ s|command=\"fuzzel\"|command=\"noctalia msg panel-toggle launcher\"|" \
            "$CONFIG/labwc/rc.xml"
    done
fi
install -m 0644 "$REPO_DIR/configs/waybar/config.jsonc" "$CONFIG/waybar/config.jsonc"
install -m 0644 "$REPO_DIR/configs/wlogout/layout" "$CONFIG/wlogout/layout"
install -m 0644 "$REPO_DIR/configs/gtk/settings.ini" "$CONFIG/gtk-3.0/settings.ini"
install -m 0644 "$REPO_DIR/configs/gtk/settings.ini" "$CONFIG/gtk-4.0/settings.ini"
install -m 0644 "$REPO_DIR/scripts/help.txt" "$CONFIG/labwc/help.txt"

# Voci desktop per i tool (compaiono in Fuzzel e nel menu)
cat > "$APPDATA/labwc-theme-switcher.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cambia tema Labwc
Comment=Scegli tra blu, rosso tenue e verde salvia
Exec=$HOME/.local/bin/labwc-theme-switcher
Icon=preferences-desktop-theme
Terminal=false
Categories=Settings;
Keywords=labwc;tema;tema;colori;
EOF
cat > "$APPDATA/labwc-menu-editor.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Editor menu Labwc
Comment=Aggiungi o rimuovi applicazioni dal menu del tasto destro
Exec=$HOME/.local/bin/labwc-menu-editor
Icon=applications-system
Terminal=false
Categories=Settings;Utility;
Keywords=labwc;menu;applicazioni;
EOF
cat > "$APPDATA/labwc-help.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Aiuto Labwc
Comment=Scorciatoie, configurazione e soluzioni ai problemi
Exec=$HOME/.local/bin/labwc-help
Icon=help-browser
Terminal=false
Categories=Documentation;
Keywords=labwc;aiuto;scorciatoie;
EOF
cat > "$APPDATA/labwc-update-gui.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Controlli aggiornamenti script labwc-q4os
Comment=Controlla, abilita o disabilita gli avvisi di nuova versione
Exec=$HOME/.local/bin/labwc-update-gui
Icon=software-update-available
Terminal=false
Categories=Settings;System;
Keywords=labwc;aggiornamenti;versione;update;
EOF
cat > "$APPDATA/labwc-fuzzel-apps.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=App in Fuzzel
Comment=Aggiungi o rimuovi applicazioni dal launcher Fuzzel, con icona
Exec=$HOME/.local/bin/labwc-fuzzel-apps
Icon=applications-other
Terminal=false
Categories=Settings;Utility;
Keywords=fuzzel;launcher;app;aggiungi;rimuovi;icona;
EOF
cat > "$APPDATA/labwc-login-theme.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Schermata di login
Comment=Scegli tra tre temi di login e sincronizza i colori con lo sfondo
Exec=$HOME/.local/bin/labwc-login-theme
Icon=preferences-desktop-theme
Terminal=false
Categories=Settings;System;
Keywords=login;sddm;tema;schermata;blu;rosso;verde;
EOF
cat > "$APPDATA/labwc-preferences.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Preferenze della scrivania Labwc
Comment=Tema, icone, tastiera, desktop e strumenti Labwc
Exec=$HOME/.local/bin/labwc-preferences
Icon=preferences-desktop
Terminal=false
Categories=Settings;
Keywords=labwc;preferenze;tema;tastiera;desktop;
EOF
cat > "$APPDATA/labwc-app-manager.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=App nel menu Labwc
Comment=Cerca app, tasto destro per preferiti e categorie
Exec=$HOME/.local/bin/labwc-app-manager
Icon=applications-system
Terminal=false
Categories=Settings;Utility;
Keywords=labwc;menu;preferiti;categorie;app;
EOF
cat > "$APPDATA/labwc-sysinfo.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Informazioni Labwc
Comment=Versione script, applicazioni, stato sessione e link repository
Exec=terminator -x $HOME/.local/bin/labwc-sysinfo
Icon=help-about
Terminal=false
Categories=System;Documentation;
Keywords=labwc;informazioni;versione;repo;
EOF
cat > "$APPDATA/labwc-zram.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ZRAM — Memoria compressa
Comment=Attiva, disattiva e monitora zram con indicatori grafici
Exec=$HOME/.local/bin/labwc-zram
Icon=utilities-system-monitor
Terminal=false
Categories=System;Settings;
Keywords=zram;ram;swap;memoria;prestazioni;
EOF
cat > "$APPDATA/labwc-doctor.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Diagnostica Labwc
Comment=Controlla e ripara configurazione, barra, menu e sessione Wayland
Exec=terminator -x $HOME/.local/bin/labwc-doctor --fix
Icon=applications-system
Terminal=false
Categories=System;Settings;
Keywords=labwc;diagnostica;ripara;log;
EOF
chmod 0644 "$APPDATA/labwc-theme-switcher.desktop" \
          "$APPDATA/labwc-menu-editor.desktop" \
          "$APPDATA/labwc-help.desktop" \
          "$APPDATA/labwc-zram.desktop" \
          "$APPDATA/labwc-doctor.desktop" \
          "$APPDATA/labwc-app-manager.desktop" \
          "$APPDATA/labwc-update-gui.desktop" \
          "$APPDATA/labwc-login-theme.desktop" \
          "$APPDATA/labwc-fuzzel-apps.desktop" \
          "$APPDATA/labwc-preferences.desktop" \
          "$APPDATA/labwc-sysinfo.desktop"

# Collegamenti browser: uno normale per Labwc e uno "(cage)" a schermo intero.
create_browser_shortcuts() {
    local browser="$1" name="$2" cmd="$3" icon="${4:-$1}"
    case "$WANT_BROWSER" in
        "$browser"|both) ;;
        *) return 0 ;;
    esac
    if [ "$browser" = "firefox" ]; then
        # Nasconde la voce di sistema: nel menu restano solo le due voci
        # labwc-q4os (normale e cage), senza duplicati.
        cat >"$APPDATA/firefox-esr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Firefox ESR
NoDisplay=true
EOF
    fi
    cat >"$APPDATA/$browser.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$name nella sessione Labwc
Exec=$cmd
Icon=$icon
Terminal=false
Categories=Network;WebBrowser;
Keywords=browser;web;$browser;
EOF
    cat >"$APPDATA/$browser-cage.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name (cage)
Comment=$name a schermo intero con Cage; salva i documenti prima
Exec=$HOME/.local/bin/labwc-cage --ask -- $cmd
Icon=$icon
Terminal=false
Categories=Network;WebBrowser;
Keywords=browser;web;$browser;cage;
EOF
}
create_browser_shortcuts chromium Chromium chromium
create_browser_shortcuts firefox "Firefox ESR" firefox-esr firefox-esr
if [ "$WANT_FREETUBE" -eq 1 ]; then
    cat >"$APPDATA/freetube.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=FreeTube
Comment=YouTube con GUI nella sessione Labwc
Exec=$HOME/.local/bin/labwc-freetube
Icon=video-x-generic
Terminal=false
Categories=AudioVideo;Video;
Keywords=youtube;video;freetube;cage;
EOF
    cat >"$APPDATA/freetube-cage.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=FreeTube (cage)
Comment=FreeTube a schermo intero con Cage; pulsante X per chiudere
Exec=$HOME/.local/bin/labwc-cage --ask -- $HOME/.local/bin/labwc-freetube-cage
Icon=video-x-generic
Terminal=false
Categories=AudioVideo;Video;
Keywords=youtube;video;freetube;cage;
EOF
fi
rm -f "$APPDATA/gtk-pipe-viewer.desktop" "$APPDATA/labwc-youtube.desktop"

# -----------------------------------------------------------------------------
# Sfondi: copia quelli pre-generati (istantaneo), genera solo se mancano
# -----------------------------------------------------------------------------
mkdir -p "$SHARE/wallpapers"
missing_wallpapers=0
for _wall in nordic-cobalt muted-crimson sage-emerald; do
    [ -f "$REPO_DIR/configs/wallpapers/$_wall.png" ] || missing_wallpapers=1
done
if [ "$missing_wallpapers" -eq 0 ]; then
    log "Installazione dei tre sfondi pre-generati (2560x1440)..."
    for _wall in nordic-cobalt muted-crimson sage-emerald; do
        if cmp -s "$REPO_DIR/configs/wallpapers/$_wall.png" \
            "$SHARE/wallpapers/$_wall.png"; then
            continue
        fi
        install -m 0644 "$REPO_DIR/configs/wallpapers/$_wall.png" \
            "$SHARE/wallpapers/$_wall.png"
    done
    ok "Sfondi installati in $SHARE/wallpapers"
else
    log "Sfondi pre-generati mancanti: generazione locale (2560x1440)..."
    python3 "$REPO_DIR/scripts/generate-wallpapers.py" \
        --output "$SHARE/wallpapers" \
        --width 2560 --height 1440
    ok "Sfondi generati in $SHARE/wallpapers"
fi

# -----------------------------------------------------------------------------
# Applicazione tema e menu
# -----------------------------------------------------------------------------
log "Applicazione tema $(theme_label "$THEME")..."
LABWC_Q4OS_SHARE="$SHARE" LABWC_Q4OS_SKIP_LOGIN=1 \
    bash "$REPO_DIR/scripts/labwc-theme-apply" "$THEME" --no-reload --quiet
ok "Tema applicato."

log "Generazione menu dinamico..."
python3 "$SHARE/scripts/render-menu.py" --render
ok "Menu pronto."

# -----------------------------------------------------------------------------
# Sessione Wayland nel display manager
# -----------------------------------------------------------------------------
install_sddm_theme() {
    local themes_root="$REPO_DIR/configs/sddm/themes"
    local dest="/usr/share/sddm/themes/labwc-q4os"
    local state_file="/var/lib/sddm/state.conf"
    local user_name="${USER:-$(id -un)}"
    local variant
    local selected="${SDDM_VARIANT:-$THEME}"

    [ -d "$themes_root/$selected" ] || {
        warn "Tema login $selected non trovato in $themes_root: SDDM resta invariato."
        return 0
    }

    log "Installazione dei tre temi login (Aurora Card, Split Studio, Bottom Dock)..."
    sudo install -d -m 0755 /usr/share/labwc-q4os/login-themes
    for variant in nordic-cobalt muted-crimson sage-emerald; do
        sudo rm -rf "/usr/share/labwc-q4os/login-themes/$variant"
        sudo cp -a "$themes_root/$variant" "/usr/share/labwc-q4os/login-themes/$variant"
        sudo chown -R root:root "/usr/share/labwc-q4os/login-themes/$variant"
        sudo chmod -R a+rX "/usr/share/labwc-q4os/login-themes/$variant"
    done
    if sudo /usr/local/libexec/labwc-q4os/login-theme-apply "$selected"; then
        ok "Tema login applicato: $selected ($dest)"
    else
        warn "Applicazione del tema login non riuscita: SDDM resta invariato."
    fi

    sudo install -d -m 0755 /etc/sddm.conf.d
    # 99- vince sui drop-in di Plasma (kde_settings.conf, 90-...) e sul tema
    # Breeze gia' selezionato. DisplayServer=x11 e' quello supportato dal tema.
    sudo rm -f /etc/sddm.conf.d/90-labwc-q4os.conf \
        /etc/sddm.conf.d/99-labwc-q4os.conf \
        /etc/sddm.conf.d/zz-labwc-q4os.conf
    if [ "$PLASMA_LOGIN" -eq 1 ]; then
        warn "Login SDDM/Plasma rilevato: forzo tema labwc-q4os e sessione Labwc."
    fi
    sudo tee /etc/sddm.conf.d/zz-labwc-q4os.conf >/dev/null <<EOF
# Generato da labwc-q4os — https://github.com/reverseloop-dev/labwc-q4os
# Deve restare l'ultimo drop-in: vince sui temi Plasma/Breeze.
[General]
DisplayServer=x11
InputMethod=$([ "$ENABLE_TOUCH" -eq 1 ] && echo qtvirtualkeyboard || true)

[Theme]
Current=labwc-q4os

[Users]
DefaultSession=labwc.desktop
RememberLastSession=true
ReuseSession=true
EOF
    sudo chmod 0644 /etc/sddm.conf.d/zz-labwc-q4os.conf

    sudo install -d -m 0755 /var/lib/sddm
    if [ ! -f "$state_file" ] || [ "$WANT_SDDM" -eq 1 ]; then
        sudo tee "$state_file" >/dev/null <<EOF
[Last]
User=$user_name
Session=labwc.desktop
EOF
        sudo chmod 0644 "$state_file"
        ok "Sessione predefinita SDDM: Labwc"
    elif [ "$DM_NAME" = "sddm" ]; then
        if sudo grep -q '^Session=' "$state_file"; then
            sudo sed -i 's|^Session=.*|Session=labwc.desktop|' "$state_file"
        else
            printf 'Session=labwc.desktop\n' | sudo tee -a "$state_file" >/dev/null
        fi
        sudo chmod 0644 "$state_file"
        ok "Sessione SDDM predefinita aggiornata: Labwc"
    fi
}

log "Registrazione sessione Labwc nel display manager..."
# Wrapper di sessione: garantisce HOME/config anche con login Plasma/SDDM.
sudo install -d -m 0755 /usr/local/libexec/labwc-q4os
sudo install -m 0755 "$REPO_DIR/scripts/labwc-session-launch" \
    /usr/local/libexec/labwc-q4os/labwc-session
session_tmp="$(mktemp)"
cat > "$session_tmp" <<'EOF'
[Desktop Entry]
Name=Labwc
Comment=Desktop Wayland moderno (labwc-q4os by reverseloop-dev)
Exec=/usr/local/libexec/labwc-q4os/labwc-session
TryExec=/usr/local/libexec/labwc-q4os/labwc-session
Type=Application
DesktopNames=labwc
Keywords=wayland;labwc;q4os;
EOF
sudo install -d -m 0755 /usr/share/wayland-sessions
sudo install -m 0644 "$session_tmp" /usr/share/wayland-sessions/labwc.desktop
rm -f "$session_tmp"
ok "Sessione disponibile: /usr/share/wayland-sessions/labwc.desktop"

# Helper root (aggiornamenti e tema login).
log "Installazione helper root (aggiornamenti e tema login)..."
sudo install -d -m 0755 /usr/local/libexec/labwc-q4os
sudo install -m 0755 "$REPO_DIR/scripts/labwc-update-toggle" \
    /usr/local/libexec/labwc-q4os/update-toggle
# Login: applica uno dei tre temi SDDM (sorgenti root-owned in /usr/share).
sudo install -m 0755 "$REPO_DIR/scripts/labwc-login-theme-apply" \
    /usr/local/libexec/labwc-q4os/login-theme-apply

# Preferenza login: normalmente scritta da labwc-theme-apply; default = tema.
mkdir -p "$CONFIG/labwc"
if [ ! -f "$CONFIG/labwc/login.conf" ]; then
    printf 'follow_theme=1\nvariant=%s\n' "$THEME" > "$CONFIG/labwc/login.conf"
    chmod 0644 "$CONFIG/labwc/login.conf"
fi
SDDM_VARIANT="$THEME"
if grep -q '^follow_theme=0' "$CONFIG/labwc/login.conf"; then
    saved_variant="$(sed -n 's/^variant=//p' "$CONFIG/labwc/login.conf" | head -n1)"
    case "$saved_variant" in
        nordic-cobalt|muted-crimson|sage-emerald) SDDM_VARIANT="$saved_variant" ;;
    esac
fi

install_sddm_theme

sudo install -d -m 0755 /etc/labwc-q4os
if [ ! -f /etc/labwc-q4os/update-check.enabled ]; then
    printf '1\n' | sudo tee /etc/labwc-q4os/update-check.enabled >/dev/null
    sudo chmod 0644 /etc/labwc-q4os/update-check.enabled
fi
if "$REPO_DIR/scripts/labwc-update-check" --is-enabled >/dev/null 2>&1; then
    ok "Controllo aggiornamenti: attivo (disattivabile dall'utente, riattivazione con password root)."
else
    warn "Controllo aggiornamenti disattivato; riattivalo dal pannello con la password root."
fi

if [ "$WANT_SDDM" -eq 1 ]; then
    if command -v sddm >/dev/null 2>&1; then
        log "Configurazione di SDDM come display manager..."
        sudo install -d -m 0755 /etc/X11
        if sudo systemctl enable sddm.service >/dev/null 2>&1; then
            if sudo ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service &&
               printf '/usr/bin/sddm\n' | sudo tee /etc/X11/default-display-manager >/dev/null; then
                sudo systemctl disable tdm.service tdm-trinity.service >/dev/null 2>&1 || true
                SDDM_ENABLED=1
                ok "SDDM attivato: al prossimo avvio scegli Labwc dal login."
            else
                warn "Configurazione del display manager non riuscita: TDM resta disponibile."
            fi
        else
            warn "Impossibile abilitare SDDM: TDM resta il display manager."
        fi
    else
        warn "SDDM non installato: TDM resta il display manager."
    fi
fi

if systemctl is-active --quiet tdm.service 2>/dev/null || systemctl is-active --quiet tdm-trinity.service 2>/dev/null; then
    if [ "$WANT_SDDM" -eq 1 ] && command -v sddm >/dev/null 2>&1; then
        info "TDM e' ancora attivo in questa sessione; SDDM partira' al prossimo riavvio."
    else
        warn "TDM e' attivo: alcune versioni non elencano sessioni Wayland."
        warn "Se Labwc non compare al login, usa SDDM oppure avvia 'dbus-run-session labwc' da TTY."
    fi
fi

# -----------------------------------------------------------------------------
# Ottimizzazioni memoria
# -----------------------------------------------------------------------------
if command -v zramctl >/dev/null 2>&1; then
    log "Configurazione zram (zstd, 50%, priorita' 100)..."
    mkdir -p "$BACKUP_DIR/system"
    if [ -r /etc/default/zramswap ]; then
        # shellcheck disable=SC2024
        sudo cat /etc/default/zramswap > "$BACKUP_DIR/system/zramswap" 2>/dev/null || true
    fi
    sudo tee /etc/default/zramswap >/dev/null <<'EOF'
# Generato da labwc-q4os — https://github.com/reverseloop-dev/labwc-q4os
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

    if [ "$ENABLE_ZRAM" -eq 1 ]; then
        zram_started=0
        sudo modprobe zram >/dev/null 2>&1 || true
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl enable --now zramswap.service >/dev/null 2>&1 || true
            if command -v zramctl >/dev/null 2>&1 && [ -n "$(zramctl 2>/dev/null)" ]; then
                zram_started=1
            elif [ -e /dev/zram0 ]; then
                zram_started=1
            else
                warn "zramswap.service non avviato: verifica con 'systemctl status zramswap'."
            fi
        else
            sudo modprobe zram && zram_started=1 || warn "modprobe zram fallito."
        fi
        if [ "$zram_started" -eq 1 ]; then
            ok "zram attivo e abilitato all'avvio."
        else
            warn "zram configurato ma non attivo; attivalo dal menu ZRAM."
        fi
    else
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl disable --now zramswap.service >/dev/null 2>&1 || true
        fi
        ok "zram configurato ma non attivo (attivabile dal menu: ZRAM - memoria compressa)."
    fi
else
    warn "zramctl non disponibile: configurazione zram saltata."
fi

if [ "$ENABLE_SWAPPINESS" -eq 1 ]; then
    log "Configurazione parametri memoria (swappiness=$SWAPPINESS_VALUE)..."
    mkdir -p "$BACKUP_DIR/system"
    if [ -r /etc/sysctl.d/99-labwc-performance.conf ]; then
        # shellcheck disable=SC2024
        sudo cat /etc/sysctl.d/99-labwc-performance.conf > "$BACKUP_DIR/system/99-labwc-performance.conf" 2>/dev/null || true
    fi
    {
        printf '# Generato da labwc-q4os — https://github.com/reverseloop-dev/labwc-q4os\n'
        printf '# zram: %s\n' "$([ "$ENABLE_ZRAM" -eq 1 ] && echo si || echo no)"
        printf 'vm.swappiness=%s\n' "$SWAPPINESS_VALUE"
        printf 'vm.vfs_cache_pressure=50\n'
        if [ "$ENABLE_ZRAM" -eq 1 ]; then
            printf 'vm.page-cluster=0\n'
        fi
    } | sudo tee /etc/sysctl.d/99-labwc-performance.conf >/dev/null
    if sudo sysctl -p /etc/sysctl.d/99-labwc-performance.conf >/dev/null 2>&1; then
        ok "Parametri memoria applicati."
    else
        sudo sysctl --system >/dev/null 2>&1 || warn "sysctl ha segnalato errori."
        warn "Verifica i parametri con: sysctl vm.swappiness vm.vfs_cache_pressure"
    fi
fi

# Opzioni persistenti: l'aggiornamento in-app le riusa invece dei default.
keep_tdm=0
if { [ "$DM_NAME" = "tdm" ] || [ "$DM_NAME" = "tdm-trinity" ]; } && [ "$WANT_SDDM" -eq 0 ]; then
    keep_tdm=1
fi
sudo tee /etc/labwc-q4os/install-options >/dev/null <<EOF
SHELL=$WANT_SHELL
TOUCH=$ENABLE_TOUCH
LOOKSWITCHER=$WANT_LOOKSWITCHER
ZRAM=$ENABLE_ZRAM
SWAPPINESS_ENABLED=$ENABLE_SWAPPINESS
SWAPPINESS_VALUE=$SWAPPINESS_VALUE
THEME=$THEME
BROWSER=$WANT_BROWSER
QPDFVIEW=$WANT_QPDFVIEW
FREETUBE=$WANT_FREETUBE
KEYBOARD=$XKB_LAYOUT
KEEP_TDM=$keep_tdm
EOF
sudo chmod 0644 /etc/labwc-q4os/install-options

log "Esecuzione della diagnostica finale..."
if ! LABWC_Q4OS_SHARE="$SHARE" bash "$REPO_DIR/scripts/labwc-doctor" --quiet; then
    warn "La diagnostica ha segnalato errori. Apri 'Diagnostica e ripara desktop' dal menu."
fi

# -----------------------------------------------------------------------------
# Verifica finale
# -----------------------------------------------------------------------------
log "Verifica finale..."
[ -x "$CONFIG/labwc/autostart" ] || die "autostart non eseguibile."
[ -f "$CONFIG/waybar/style.css" ] || die "style.css di Waybar mancante."
[ -f "$CONFIG/fuzzel/fuzzel.ini" ] || die "fuzzel.ini mancante."
[ -f "$CONFIG/labwc/themerc-override" ] || die "themerc-override mancante."
[ -f "$CONFIG/labwc/shell" ] || die "marker shell mancante."
[ -f "$SHARE/wallpapers/$THEME.png" ] || die "sfondo del tema mancante."
[ -f "$CONFIG/labwc/menu.xml" ] || die "menu.xml mancante."
[ -f "$SHARE/VERSION" ] || die "VERSION mancante."
[ -f "$SHARE/version-info" ] || die "version-info mancante."
[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/icons/labwc-q4os/index.theme" ] || die "icon theme labwc-q4os mancante."
[ -x /usr/local/libexec/labwc-q4os/login-theme-apply ] || die "helper tema login mancante."
[ -x /usr/local/libexec/labwc-q4os/labwc-session ] || die "wrapper sessione labwc mancante."
grep -q 'Exec=/usr/local/libexec/labwc-q4os/labwc-session' /usr/share/wayland-sessions/labwc.desktop ||
    die "file sessione labwc non punta al wrapper."
[ -f "$APPDATA/labwc-preferences.desktop" ] || die "voci .desktop mancanti in $APPDATA."
for variant in nordic-cobalt muted-crimson sage-emerald; do
    [ -f "/usr/share/labwc-q4os/login-themes/$variant/Main.qml" ] ||
        die "tema login mancante: $variant"
done
for helper in labwc-theme-switcher labwc-menu-editor labwc-help labwc-reload labwc-screenshot labwc-zram labwc-doctor labwc-app-manager labwc-update-check labwc-update-copy labwc-update-popup labwc-update-run labwc-update-gui labwc-preferences labwc-desktop labwc-desktop-state labwc-desktop-status labwc-desktop-menu labwc-power-menu labwc-sysinfo labwc-touchscreen labwc-touch-tap labwc-login-theme labwc-fuzzel-apps labwc-minimized labwc-install-wizard labwc-cage labwc-freetube labwc-freetube-cage freetube-close-overlay labwc-cage-help; do
    [ -x "$BIN/$helper" ] || die "helper non eseguibile: $helper"
done
ok "Tutto in ordine."

# Dopo una rimozione (es. Chromium) il menu deve essere ricaricato subito:
# senza reconfigure labwc continuerebbe a mostrare il vecchio menu in memoria.
if [ -n "${WAYLAND_DISPLAY:-}" ] && pgrep -x labwc >/dev/null 2>&1 &&
    [ -x "$BIN/labwc-reload" ]; then
    LABWC_Q4OS_SILENT=1 "$BIN/labwc-reload" >>"$STATE/session.log" 2>&1 ||
        warn "Ricarica desktop non riuscita: usa 'Ricarica menu e desktop'."
    ok "Desktop e menu ricaricati (app rimosse/aggiunte subito)."
fi

ZRAM_STATE="configurato ma non attivo"
if command -v zramctl >/dev/null 2>&1 && [ -n "$(zramctl 2>/dev/null)" ]; then
    ZRAM_STATE="attivo"
elif [ "$ENABLE_ZRAM" -eq 1 ]; then
    ZRAM_STATE="configurato, servizio non ancora attivo"
fi

cat <<EOF

${C_GREEN}${C_BOLD}Installazione completata.${C_RESET}

  Tema attivo ........ $(theme_label "$THEME")
  Shell .............. $([ "$WANT_SHELL" = "noctalia" ] && echo "Noctalia v5 (barra, launcher, notifiche, sfondo, lock)" || echo "Waybar + Fuzzel")
  Trinity ............ $([ "$WANT_LOOKSWITCHER" -eq 1 ] && echo "LookSwitcher installato (solo sessione Trinity)" || echo "invariato")
  Layout tastiera .... $XKB_LAYOUT (login: $XKB_PRIMARY)
  Touchscreen ........ $([ "$ENABLE_TOUCH" -eq 1 ] && echo "wvkbd + lisgd (swipe dal basso per la tastiera)" || echo "no")
  Display manager .... $([ "$SDDM_ENABLED" -eq 1 ] && echo "SDDM (attivo al prossimo riavvio)" || echo "invariato")
  Login .............. tema $(tr -d '[:space:]' < "$CONFIG/labwc/theme") (3 temi disponibili)
  Sfondi ............. $SHARE/wallpapers
  Menu ............... $CONFIG/labwc/menu.xml
  Preferite .......... $CONFIG/labwc/favorites.tsv
  zram ............... $ZRAM_STATE (pannello nel menu)
  swappiness ......... $([ "$ENABLE_SWAPPINESS" -eq 1 ] && echo "$SWAPPINESS_VALUE" || echo "invariato")
  Browser ............ $(browser_label "$WANT_BROWSER")$(
      case "$WANT_BROWSER" in
          chromium)
              if have chromium || have chromium-browser; then
                  echo " (uBlock Origin Lite, Privacy Badger, enhanced-h264ify)"
              fi ;;
          firefox)
              if have firefox-esr; then
                  echo " (uBlock Origin, Privacy Badger, enhanced-h264ify)"
              fi ;;
      esac
  )
  qpdfview ........... $(if have qpdfview; then echo "installato"; else echo "non installato"; fi)
  FreeTube ........... $(if command -v freetube >/dev/null 2>&1; then echo "installato (.deb)"; else echo "non installato"; fi)
  btop ............... $(if have btop; then echo "installato"; else echo "non installato"; fi)
  Backup ............. $BACKUP_DIR
  Log sessione ....... $STATE/session.log

${C_BOLD}Prossimi passi${C_RESET}
  1. $([ "$SDDM_ENABLED" -eq 1 ] && echo "Riavvia il sistema per passare a SDDM." || echo "Esci dalla sessione corrente.").
  2. Nel display manager scegli la sessione ${C_BOLD}Labwc${C_RESET}.
     $([ "$SDDM_ENABLED" -eq 1 ] && echo "SDDM mostra le sessioni in basso a sinistra." || echo "Su TDM: Menu > Session Type > Labwc.").
  3. $([ "$WANT_SHELL" = "noctalia" ] && echo "Al primo login Noctalia (barra, notifiche e sfondo) parte da sola." || echo "Al primo login Waybar, Mako e lo sfondo partono da soli.").
  4. Se Labwc non compare, la diagnostica ti dice cosa fare:
       labwc-doctor --fix-system

${C_BOLD}Da ricordare${C_RESET}
  Super+D .............. $([ "$WANT_SHELL" = "noctalia" ] && echo "launcher Noctalia" || echo "Fuzzel (launcher)")
  Super+Invio .......... terminale Terminator
  Tasto destro ......... menu completo + gestione app preferite
  Doppio clic sinistro . aiuto, scorciatoie e informazioni di sistema
  Tasto destro ......... ZRAM — memoria compressa (attiva/disattiva)
  Super+Shift+R ........ ricarica menu e desktop
  Super+Shift+T ........ cambia tema
  Super+Shift+H ........ aiuto completo
  labwc-doctor ......... controlli e riparazione

Se stai gia' usando labwc, applica subito le modifiche con:
  labwc-reload

EOF

printf '\n%s' "$C_CYAN"
printf '%s\n' '  .-----------------------------------------------------.'
printf '%s\n' '  |          created by reverseloop-dev                 |'
printf '%s\n' "  '-----------------------------------------------------'"
printf '%s\n' "$C_RESET"

trap - ERR
exit 0
