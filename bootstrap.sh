#!/usr/bin/env bash
# =============================================================================
#  labwc-q4os — bootstrap per installazione one-liner
#
#  Usa una copia cache del repository e scarica solo le modifiche (fetch
#  incrementale). Verifica sempre origin, SHA256SUMS e ancora di fiducia.
#  Con LABWC_Q4OS_FRESH=1 ignora la cache e clona in una directory temporanea.
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/reverseloop-dev/labwc-q4os.git"
REPO_HTTPS="https://github.com/reverseloop-dev/labwc-q4os"
CACHE="${LABWC_Q4OS_CACHE:-$HOME/.cache/labwc-q4os-src}"
MANIFEST_SHA256="ade510fcaddc8456d30b800a04ea1e14ee529c82696c471fd2396b80a4fdacd0"

die() { printf '[labwc-q4os] ERRORE: %s\n' "$*" >&2; exit 1; }

if ! command -v git >/dev/null 2>&1; then
    die "git non trovato. Su Q4OS/Debian: sudo apt install git"
fi
if ! command -v sha256sum >/dev/null 2>&1; then
    die "sha256sum non trovato (pacchetto coreutils)."
fi

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

cache_usable=0
if [ "${LABWC_Q4OS_FRESH:-0}" != "1" ] && [ -d "$CACHE/.git" ]; then
    cache_origin="$(git -C "$CACHE" remote get-url origin 2>/dev/null || true)"
    case "$cache_origin" in
        "$REPO_URL"|"$REPO_HTTPS"|"$REPO_HTTPS.git") cache_usable=1 ;;
    esac
fi

if [ "$cache_usable" -eq 1 ]; then
    DEST="$CACHE"
    printf '[labwc-q4os] Aggiornamento incrementale dalla cache...\n'
    git -c core.hooksPath=/dev/null -c core.fsmonitor=false \
        -C "$DEST" fetch --depth 1 origin main >/dev/null 2>&1 ||
        die "fetch incrementale non riuscito (usa LABWC_Q4OS_FRESH=1)."
    git -c core.hooksPath=/dev/null -c core.fsmonitor=false \
        -C "$DEST" reset --hard FETCH_HEAD >/dev/null 2>&1 ||
        die "reset della cache non riuscito."
    git -C "$DEST" clean -fdx >/dev/null 2>&1 || true
else
    if [ ! -e "$CACHE" ]; then
        mkdir -p "$(dirname "$CACHE")"
        printf '[labwc-q4os] Primo download sorgenti verificati...\n'
        if git clone --depth 1 --branch main "$REPO_URL" "$CACHE"; then
            DEST="$CACHE"
        else
            rm -rf "$CACHE"
            DEST=""
        fi
    fi
    if [ -z "${DEST:-}" ]; then
        WORK="$(mktemp -d "${TMPDIR:-/tmp}/labwc-q4os.XXXXXX")"
        chmod 0700 "$WORK"
        DEST="$WORK/src"
        printf '[labwc-q4os] Download sorgenti verificati...\n'
        git clone --depth 1 --branch main "$REPO_URL" "$DEST" ||
            die "clone del repository non riuscito."
    fi
fi

origin="$(git -C "$DEST" remote get-url origin 2>/dev/null || true)"
case "$origin" in
    "$REPO_URL"|"$REPO_HTTPS"|"$REPO_HTTPS.git") ;;
    *) die "repository inatteso: '$origin' (atteso $REPO_URL)." ;;
esac

[ -f "$DEST/SHA256SUMS" ] || die "SHA256SUMS mancante: repository non verificabile."
actual_manifest="$(sha256sum "$DEST/SHA256SUMS" | cut -d' ' -f1)"
if [ "$actual_manifest" != "$MANIFEST_SHA256" ]; then
    die "SHA256SUMS non corrisponde all'ancora di fiducia (atteso $MANIFEST_SHA256, trovato $actual_manifest)."
fi

if ! (cd "$DEST" && sha256sum -c --strict --quiet SHA256SUMS); then
    die "verifica integrita' fallita: uno o piu' file del repository sono stati modificati."
fi
printf "[labwc-q4os] Integrita' verificata (%s).\n" "$actual_manifest"

bash "$DEST/install.sh" "$@"
