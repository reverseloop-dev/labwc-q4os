#!/usr/bin/env bash
# =============================================================================
#  labwc-q4os — bootstrap per installazione one-liner
#
#  Clona il repository in una directory temporanea privata, verifica che i
#  file non siano stati modificati (SHA256SUMS con hash del manifest fissato
#  qui sotto) e lancia install.sh.
#
#  ATTENZIONE: questa e' una verifica di INTEGRITA', non di autenticita'.
#  Se il repository main e questo bootstrap vengono compromessi insieme,
#  l'ancora di fiducia e' compromessa. Per la massima sicurezza scarica il
#  bootstrap da una release firmata e confronta il suo SHA256 con quello
#  pubblicato ufficialmente, poi eseguilo.
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/reverseloop-dev/labwc-q4os.git"
REPO_HTTPS="https://github.com/reverseloop-dev/labwc-q4os"
# Hash del file SHA256SUMS del repository (aggiornato a ogni release da
# scripts/make-checksums). Se un file viene modificato, la verifica fallisce.
MANIFEST_SHA256="1b5de581aaf8122999b82264517306df861aad6284ee9e4b0ca725ca08780581"

die() { printf '[labwc-q4os] ERRORE: %s\n' "$*" >&2; exit 1; }

if ! command -v git >/dev/null 2>&1; then
    die "git non trovato. Su Q4OS/Debian: sudo apt install git"
fi
if ! command -v sha256sum >/dev/null 2>&1; then
    die "sha256sum non trovato (pacchetto coreutils)."
fi

# Directory temporanea privata: nessun riuso di cache scrivibile, nessun
# rischio di cancellare una directory esistente indicata dall'utente.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/labwc-q4os.XXXXXX")"
chmod 0700 "$WORK"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
DEST="$WORK/src"

printf '[labwc-q4os] Download sorgenti verificati...\n'
git clone --depth 1 --branch main "$REPO_URL" "$DEST" ||
    die "clone del repository non riuscito."

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
