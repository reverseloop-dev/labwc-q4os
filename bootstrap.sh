#!/usr/bin/env bash
# =============================================================================
#  labwc-q4os — bootstrap per installazione one-liner
#  Clona/aggiorna il repository e lancia install.sh
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/reverseloop-dev/labwc-q4os.git"
DEST="${LABWC_Q4OS_DIR:-$HOME/.cache/labwc-q4os-src}"

if ! command -v git >/dev/null 2>&1; then
    printf 'git non trovato. Su Q4OS/Debian: sudo apt install git\n' >&2
    exit 1
fi

if [ -d "$DEST/.git" ]; then
    printf '[labwc-q4os] Aggiornamento sorgenti in %s...\n' "$DEST"
    git -C "$DEST" pull --ff-only || {
        printf 'Aggiornamento fallito, uso la copia esistente.\n' >&2
    }
else
    printf '[labwc-q4os] Download sorgenti in %s...\n' "$DEST"
    mkdir -p "$(dirname "$DEST")"
    rm -rf "$DEST"
    git clone --depth 1 "$REPO_URL" "$DEST"
fi

exec bash "$DEST/install.sh" "$@"
