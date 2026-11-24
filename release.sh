#!/usr/bin/env bash
# Publie une release GitHub avec l'APK signé en pièce jointe (lu par Obtainium).
# Usage : ./release.sh
# Jeton lu dans ~/.config/compteurs-lies/github.env (GITHUB_TOKEN=..., chmod 600) ou l'environnement.
# Dépôt déduit du remote git "origin" (ou GITHUB_REPO=utilisateur/depot).
# Le jeton doit avoir le droit "Contents: Read and write" sur le dépôt (fine-grained token).
set -euo pipefail

cd "$(dirname "$0")"
ENV_FILE="${ENV_FILE:-$HOME/.config/compteurs-lies/github.env}"
if [[ -z "${GITHUB_TOKEN:-}" && -f "$ENV_FILE" ]]; then set -a; . "$ENV_FILE"; set +a; fi
: "${GITHUB_TOKEN:?GITHUB_TOKEN manquant}"
GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')}"
: "${GITHUB_REPO:?dépôt GitHub introuvable}"
API="https://api.github.com/repos/$GITHUB_REPO"

log() { echo "[release] $*"; }
trap 'log "ÉCHEC ligne $LINENO"' ERR

# Version lue dans le manifeste : tag vX.Y
VERSION=$(sed -n 's/.*android:versionName="\([^"]*\)".*/\1/p' AndroidManifest.xml)
TAG="v$VERSION"
APK="build/compteurs-lies.apk"
ASSET="compteurs-lies-$TAG.apk"

[[ -n "$VERSION" ]] || { log "versionName introuvable"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { log "Arbre git non propre : committer d'abord"; exit 1; }

log "Build de l'APK $TAG…"
./build.sh >/dev/null

auth=(-H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json")

if curl -fsS "${auth[@]}" "$API/releases/tags/$TAG" >/dev/null 2>&1; then
  log "La release $TAG existe déjà : incrémenter versionCode/versionName"; exit 1
fi

log "Push du code et du tag $TAG…"
git tag -a "$TAG" -m "Compteurs liés $VERSION"
# Authentification par en-tête : le jeton n'est jamais écrit dans .git/config
basic=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)
git -c http.extraHeader="Authorization: Basic $basic" push origin HEAD "$TAG"

log "Création de la release…"
body=$(printf '{"tag_name":"%s","name":"Compteurs liés %s","body":"APK signé : %s"}' "$TAG" "$VERSION" "$ASSET")
upload_url=$(curl -fsS "${auth[@]}" -X POST "$API/releases" -d "$body" \
  | sed -n 's/.*"upload_url": *"\([^{"]*\).*/\1/p')
[[ -n "$upload_url" ]] || { log "upload_url introuvable"; exit 1; }

log "Envoi de $ASSET…"
curl -fsS "${auth[@]}" -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary @"$APK" "$upload_url?name=$ASSET" >/dev/null
log "OK : https://github.com/$GITHUB_REPO/releases/tag/$TAG"
