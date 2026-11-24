#!/usr/bin/env bash
# Construit et signe build/compteurs-lies.apk sans Gradle (aapt2 + javac + d8 + apksigner).
set -euo pipefail

cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-35/android.jar"
OUT=build
APK="$OUT/compteurs-lies.apk"
# Keystore hors du dépôt ; mot de passe surchargeable par variable d'environnement
KEYSTORE="${KEYSTORE:-$HOME/.android/compteurs-lies.jks}"
KS_PASS="${KS_PASS:-compteurs-lies}"

log() { echo "[build] $*"; }
trap 'log "ÉCHEC ligne $LINENO"' ERR

[[ -f "$JAR" && -x "$BT/aapt2" ]] || { log "SDK absent : lancer ./install-sdk.sh"; exit 1; }

# Nettoyage ciblé du seul dossier de build
if [[ -d "$OUT" ]]; then find "$OUT" -mindepth 1 -delete; fi
mkdir -p "$OUT/res" "$OUT/gen" "$OUT/classes"

log "Ressources (aapt2)…"
"$BT/aapt2" compile --dir res -o "$OUT/res/res.zip"
"$BT/aapt2" link -o "$OUT/unsigned.apk" -I "$JAR" \
  --manifest AndroidManifest.xml -A assets \
  --java "$OUT/gen" "$OUT/res/res.zip"

log "Compilation Java…"
javac --release 11 -classpath "$JAR" -d "$OUT/classes" \
  $(find src "$OUT/gen" -name '*.java')

log "DEX (d8)…"
"$BT/d8" --min-api 24 --lib "$JAR" --output "$OUT" $(find "$OUT/classes" -name '*.class')
(cd "$OUT" && zip -qj unsigned.apk classes.dex)

log "Alignement…"
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

if [[ ! -f "$KEYSTORE" ]]; then
  log "Création du keystore $KEYSTORE (à conserver : nécessaire pour les mises à jour)…"
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -alias app -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=Compteurs lies" -noprompt
fi

log "Signature…"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-key-alias app \
  --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
  --out "$APK" "$OUT/aligned.apk"
"$BT/apksigner" verify "$APK"
log "OK : $(pwd)/$APK"
