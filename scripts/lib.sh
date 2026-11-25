#!/usr/bin/env bash
# =============================================================================
#  labwc-q4os - libreria comune (log, colori, prompt, helper)
#  Parte del progetto https://github.com/reverseloop-dev/labwc-q4os
# =============================================================================

# Evita doppio sourcing
# shellcheck disable=SC2317
if [ "${LABWC_Q4OS_LIB_LOADED:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
LABWC_Q4OS_LIB_LOADED=1

# Colori solo se il terminale li supporta
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    # shellcheck disable=SC2034
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    # shellcheck disable=SC2034
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW=''
    C_BLUE='' C_CYAN=''
fi

log()  { printf '%s[labwc-q4os]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()   { printf '%s[  OK  ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
info() { printf '%s[ info ]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
warn() { printf '%s[ warn ]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[ errore ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

err_trap() {
    local line="${1:-?}"
    err "Comando fallito (riga ${line}). Installazione interrotta."
    err "Nessuna configurazione preesistente e' stata cancellata: i backup sono in ${BACKUP_DIR:-~/.local/share/labwc-q4os/backups}."
    exit 1
}

# Prompt si/no. Primo argomento: domanda. Secondo: default (yes/no).
ask_yes_no() {
    local question="$1" default="${2:-yes}" answer prompt
    if [ "$default" = "yes" ]; then prompt="[S/n]"; else prompt="[s/N]"; fi

    # Senza terminale interattivo usa il default (utile in CI)
    if [ ! -r /dev/tty ]; then
        [ "$default" = "yes" ]
        return
    fi

    while true; do
        printf '%s%s%s %s ' "$C_BOLD" "$question" "$C_RESET" "$prompt" >/dev/tty
        read -r answer </dev/tty || answer=""
        answer="${answer,,}"
        case "$answer" in
            "") [ "$default" = "yes" ] && return 0 || return 1 ;;
            s|si|sì|y|yes) return 0 ;;
            n|no) return 1 ;;
            *) printf 'Rispondere con S oppure N.\n' >/dev/tty ;;
        esac
    done
}

# Prompt con scelta libera validata da una lista
ask_choice() {
    local question="$1" default="$2"; shift 2
    local answer
    if [ ! -r /dev/tty ]; then
        printf '%s\n' "$default"
        return
    fi
    while true; do
        printf '%s%s%s [%s] ' "$C_BOLD" "$question" "$C_RESET" "$default" >/dev/tty
        read -r answer </dev/tty || answer=""
        answer="${answer:-$default}"
        local valid
        for valid in "$@"; do
            if [ "$answer" = "$valid" ]; then
                printf '%s\n' "$answer"
                return
            fi
        done
        printf 'Scelta non valida. Opzioni: %s\n' "$*" >/dev/tty
    done
}

have() { command -v "$1" >/dev/null 2>&1; }

note() {
    if [ -r /dev/tty ]; then
        printf '  %s\n' "$*" >/dev/tty
    else
        printf '  %s\n' "$*"
    fi
}

# Prompt libero con default e validazione regex opzionale.
ask_input() {
    local question="$1" default="$2" pattern="${3:-}" answer
    if [ ! -r /dev/tty ]; then
        printf '%s\n' "$default"
        return
    fi
    while true; do
        printf '%s%s%s [%s] ' "$C_BOLD" "$question" "$C_RESET" "$default" >/dev/tty
        read -r answer </dev/tty || answer=""
        answer="${answer:-$default}"
        if [ -z "$pattern" ] || [[ "$answer" =~ $pattern ]]; then
            printf '%s\n' "$answer"
            return
        fi
        printf 'Valore non valido. Riprova.\n' >/dev/tty
    done
}
