#!/usr/bin/env bash
# Installe le strict nécessaire du SDK Android dans ~/Android/Sdk (sans sudo).
set -euo pipefail

SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
BUILD_TOOLS="35.0.0"
PLATFORM="android-35"

log() { echo "[install-sdk] $*"; }
trap 'log "ÉCHEC ligne $LINENO"' ERR

if [[ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]]; then
  tmp="$(mktemp -d)"
  log "Téléchargement des cmdline-tools…"
  curl -fsSL -o "$tmp/cmdline.zip" "$CMDLINE_ZIP_URL"
  mkdir -p "$SDK/cmdline-tools"
  unzip -q "$tmp/cmdline.zip" -d "$tmp"
  mv "$tmp/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm -f "$tmp/cmdline.zip"; rmdir "$tmp"
fi

SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
log "Acceptation des licences Android SDK…"
yes | "$SDKM" --sdk_root="$SDK" --licenses >/dev/null || true
log "Installation build-tools $BUILD_TOOLS + plateforme $PLATFORM…"
"$SDKM" --sdk_root="$SDK" "build-tools;$BUILD_TOOLS" "platforms;$PLATFORM"

# bundletool : nécessaire pour produire l'AAB (Play Store)
BUNDLETOOL_VERSION="1.17.2"
BUNDLETOOL_JAR="$SDK/bundletool/bundletool-all-$BUNDLETOOL_VERSION.jar"
if [[ ! -f "$BUNDLETOOL_JAR" ]]; then
  log "Téléchargement de bundletool $BUNDLETOOL_VERSION…"
  mkdir -p "$SDK/bundletool"
  curl -fsSL -o "$BUNDLETOOL_JAR.part" \
    "https://github.com/google/bundletool/releases/download/$BUNDLETOOL_VERSION/bundletool-all-$BUNDLETOOL_VERSION.jar"
  mv "$BUNDLETOOL_JAR.part" "$BUNDLETOOL_JAR"
fi
log "OK : $SDK"
