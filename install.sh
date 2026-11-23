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

if [ -n "$WANT_SHELL" ]; then
    case "$WANT_SHELL" in
        waybar|noctalia) ;;
        *) die "Valore --shell non valido: $WANT_SHELL (waybar|noctalia)" ;;
    esac
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
else
    XKB_LAYOUT="$DETECTED_LAYOUT"
    if [ "$ASSUME_YES" -eq 0 ] && [ -r /dev/tty ]; then
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

log "Richiesta privilegi sudo (solo per apt e file di sistema)..."
sudo -v || die "Impossibile ottenere sudo."
# rinnova il timestamp sudo durante l'installazione
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
trap 'err_trap $LINENO' ERR

# -----------------------------------------------------------------------------
# Scelte prestazioni
# -----------------------------------------------------------------------------
if [ -z "$ENABLE_ZRAM" ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
        ENABLE_ZRAM=1
    elif ask_yes_no "Attivare zram (RAM compressa zstd, 50%) per un sistema piu' reattivo?" yes; then
        ENABLE_ZRAM=1
    else
        ENABLE_ZRAM=0
    fi
fi

if [ -z "$ENABLE_SWAPPINESS" ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
        ENABLE_SWAPPINESS=1
    elif ask_yes_no "Configurare vm.swappiness e vfs_cache_pressure in modo persistente?" yes; then
        ENABLE_SWAPPINESS=1
    else
        ENABLE_SWAPPINESS=0
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
    elif ask_yes_no "Il PC che stai usando ha un touchscreen? Installa tastiera su schermo e gesti touch" "$touch_default"; then
        ENABLE_TOUCH=1
    else
        ENABLE_TOUCH=0
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
    elif ask_yes_no "Installare LookSwitcher (selettore di temi Q4OS), SOLO per la sessione Trinity? Non cambia labwc" no; then
        WANT_LOOKSWITCHER=1
    else
        WANT_LOOKSWITCHER=0
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
        elif ask_yes_no "TDM non supporta Wayland. Installare e attivare SDDM per scegliere Labwc al login?" yes; then
            WANT_SDDM=1
        else
            WANT_SDDM=0
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
        choice="$(ask_choice "Tema iniziale (1=blu, 2=rosso tenue, 3=verde salvia)" "$default_choice" 1 2 3)"
        case "$choice" in
            1) THEME="nordic-cobalt" ;;
            2) THEME="muted-crimson" ;;
            3) THEME="sage-emerald" ;;
        esac
    fi
fi

printf '\n%sRiepilogo:%s tema %s, shell %s, zram %s, swappiness %s, touchscreen %s\n\n' \
    "$C_BOLD" "$C_RESET" "$(theme_label "$THEME")" \
    "$([ "$WANT_SHELL" = "noctalia" ] && echo "Noctalia v5" || echo "Waybar + Fuzzel")" \
    "$([ "$ENABLE_ZRAM" -eq 1 ] && echo attivo || echo no)" \
    "$([ "$ENABLE_SWAPPINESS" -eq 1 ] && echo "${SWAPPINESS_VALUE:-auto}" || echo invariato)" \
    "$([ "$ENABLE_TOUCH" -eq 1 ] && echo si || echo no)"

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
    gvfs
    xwayland
    xauth
    chromium
    xdg-desktop-portal
    curl
    python3-pil
    python3-gi
    python3-gi-cairo
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
                https://pkg.noctalia.dev/deb/noctalia-trixie.sources ||
            ! sudo dpkg -i "$tmp/nickh-archive-keyring.deb" ||
            ! sudo install -m 0644 "$tmp/noctalia-trixie.sources" \
                /etc/apt/sources.list.d/noctalia-trixie.sources; then
            rm -rf "$tmp"
            warn "Repository Noctalia: download o installazione di keyring/sources non riusciti."
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
    ok "Noctalia v5 installato (repository di terze parti pkg.noctalia.dev)."
}

install_browser_extensions() {
    local policy_dir="/etc/chromium/policies/managed"
    local policy_file="$policy_dir/labwc-q4os-extensions.json"

    if ! have chromium && ! have chromium-browser; then
        warn "Chromium non installato: estensioni non configurate."
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
    # pkehgijcmpdhfbdbbnkijodmdjhbjlgp = Privacy Badger.
    sudo tee "$policy_file" >/dev/null <<'EOF'
{
  "ExtensionSettings": {
    "ddkjiahejlhfcafbddmgiahcphecmpfh": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    },
    "pkehgijcmpdhfbdbbnkijodmdjhbjlgp": {
      "installation_mode": "force_installed",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  }
}
EOF
    sudo chmod 0644 "$policy_file"
    ok "Chromium: uBlock Origin Lite e Privacy Badger installate da policy al primo avvio."
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
        # Una sola shell: con Noctalia non installiamo Waybar/Mako/swaybg.
        # Fuzzel resta per gli strumenti del progetto (menu, temi), non come launcher.
        shell_core=()
        for pkg in "${CORE_PKGS[@]}"; do
            case "$pkg" in
                waybar|mako-notifier|swaybg) continue ;;
            esac
            shell_core+=("$pkg")
        done
        install_packages "${shell_core[@]}"
    else
        install_packages "${CORE_PKGS[@]}"
    fi
    log "Installazione pacchetti opzionali consigliati..."
    install_packages "${OPTIONAL_PKGS[@]}"

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

log "Configurazione Chromium ed estensioni (uBlock Origin Lite, Privacy Badger)..."
install_browser_extensions

required_cmds=(labwc fuzzel foot python3)
[ "$WANT_SHELL" = "waybar" ] && required_cmds+=(waybar)
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
    labwc-login-theme \
    labwc-fuzzel-apps \
    labwc-session-start
do
    install -m 0755 "$REPO_DIR/scripts/$helper" "$BIN/$helper"
done

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
    # Palette derivata dallo sfondo e modalita' scura (file hot-reloadato).
    mkdir -p "$CONFIG/noctalia"
    cat > "$CONFIG/noctalia/config.toml" <<'EOF'
# Generato da labwc-q4os — https://github.com/reverseloop-dev/labwc-q4os
[theme]
mode = "dark"
source = "wallpaper"
EOF
    chmod 0644 "$CONFIG/noctalia/config.toml"
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
    # Super+D apre il launcher di Noctalia; Fuzzel resta installato per gli
    # strumenti del progetto. Il template rc.xml non viene modificato.
    sed -i '/<keybind key="W-d">/,/<\/keybind>/ s|command="fuzzel"|command="noctalia msg panel-toggle launcher"|' \
        "$CONFIG/labwc/rc.xml"
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

# -----------------------------------------------------------------------------
# Generazione sfondi
# -----------------------------------------------------------------------------
log "Generazione dei tre sfondi (2560x1440)..."
python3 "$REPO_DIR/scripts/generate-wallpapers.py" \
    --output "$SHARE/wallpapers" \
    --width 2560 --height 1440
ok "Sfondi generati in $SHARE/wallpapers"

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
    sudo rm -f /etc/sddm.conf.d/90-labwc-q4os.conf
    if [ "$PLASMA_LOGIN" -eq 1 ]; then
        warn "Login SDDM/Plasma rilevato: forzo tema labwc-q4os e sessione Labwc."
    fi
    sudo tee /etc/sddm.conf.d/99-labwc-q4os.conf >/dev/null <<'EOF'
# Generato da labwc-q4os — https://github.com/reverseloop-dev/labwc-q4os
# Deve restare l'ultimo drop-in: vince sui temi Plasma/Breeze.
[General]
DisplayServer=x11

[Theme]
Current=labwc-q4os

[Users]
DefaultSession=labwc.desktop
RememberLastSession=true
ReuseSession=true
EOF
    sudo chmod 0644 /etc/sddm.conf.d/99-labwc-q4os.conf

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
# Aggiornamento dalla GUI: un solo prompt polkit, log in finestra.
sudo install -m 0755 "$REPO_DIR/scripts/labwc-update-apply" \
    /usr/local/libexec/labwc-q4os/update-apply
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
        if command -v systemctl >/dev/null 2>&1; then
            if sudo systemctl enable --now zramswap.service >/dev/null 2>&1; then
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
[ -x /usr/local/libexec/labwc-q4os/update-apply ] || die "helper aggiornamento GUI mancante."
[ -x /usr/local/libexec/labwc-q4os/login-theme-apply ] || die "helper tema login mancante."
[ -x /usr/local/libexec/labwc-q4os/labwc-session ] || die "wrapper sessione labwc mancante."
grep -q 'Exec=/usr/local/libexec/labwc-q4os/labwc-session' /usr/share/wayland-sessions/labwc.desktop ||
    die "file sessione labwc non punta al wrapper."
[ -f "$APPDATA/labwc-preferences.desktop" ] || die "voci .desktop mancanti in $APPDATA."
for variant in nordic-cobalt muted-crimson sage-emerald; do
    [ -f "/usr/share/labwc-q4os/login-themes/$variant/Main.qml" ] ||
        die "tema login mancante: $variant"
done
for helper in labwc-theme-switcher labwc-menu-editor labwc-help labwc-reload labwc-screenshot labwc-zram labwc-doctor labwc-app-manager labwc-update-check labwc-update-copy labwc-update-popup labwc-update-run labwc-update-gui labwc-preferences labwc-desktop labwc-desktop-state labwc-desktop-status labwc-desktop-menu labwc-power-menu labwc-sysinfo labwc-touchscreen labwc-login-theme labwc-fuzzel-apps; do
    [ -x "$BIN/$helper" ] || die "helper non eseguibile: $helper"
done
ok "Tutto in ordine."

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
  Chromium ........... $(if have chromium || have chromium-browser; then echo "installato con estensioni (uBlock Origin Lite, Privacy Badger)"; else echo "non installato"; fi)
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

Repository: https://github.com/reverseloop-dev/labwc-q4os
EOF

trap - ERR
exit 0
