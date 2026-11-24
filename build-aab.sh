#!/usr/bin/env bash
# Construit et signe build/compteurs-lies.aab (Android App Bundle pour le Play Store).
# Réutilise les mêmes sources et le même keystore que build.sh.
set -euo pipefail

cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-35/android.jar"
BUNDLETOOL="$SDK/bundletool/bundletool-all-1.17.2.jar"
OUT=build/aab
AAB=build/compteurs-lies.aab
KEYSTORE="${KEYSTORE:-$HOME/.android/compteurs-lies.jks}"
KS_PASS="${KS_PASS:-compteurs-lies}"

log() { echo "[build-aab] $*"; }
trap 'log "ÉCHEC ligne $LINENO"' ERR

[[ -f "$JAR" && -x "$BT/aapt2" && -f "$BUNDLETOOL" ]] || { log "SDK/bundletool absent : lancer ./install-sdk.sh"; exit 1; }

# Nettoyage ciblé du seul dossier de travail AAB
if [[ -d "$OUT" ]]; then find "$OUT" -mindepth 1 -delete; fi
rm -f "$AAB"
mkdir -p "$OUT/res" "$OUT/gen" "$OUT/classes" "$OUT/proto" "$OUT/base/manifest" "$OUT/base/dex"

log "Ressources au format protobuf (aapt2 --proto-format)…"
"$BT/aapt2" compile --dir res -o "$OUT/res/res.zip"
"$BT/aapt2" link --proto-format -o "$OUT/proto.apk" -I "$JAR" \
  --manifest AndroidManifest.xml -A assets \
  --java "$OUT/gen" "$OUT/res/res.zip"

log "Compilation Java + DEX…"
javac --release 11 -classpath "$JAR" -d "$OUT/classes" $(find src "$OUT/gen" -name '*.java')
"$BT/d8" --min-api 24 --lib "$JAR" --output "$OUT/base/dex" $(find "$OUT/classes" -name '*.class')

log "Assemblage du module base (structure attendue par bundletool)…"
unzip -q "$OUT/proto.apk" -d "$OUT/proto"
mv "$OUT/proto/AndroidManifest.xml" "$OUT/base/manifest/"
mv "$OUT/proto/resources.pb" "$OUT/base/"
mv "$OUT/proto/res" "$OUT/base/"
mv "$OUT/proto/assets" "$OUT/base/"
(cd "$OUT/base" && zip -qr ../base.zip .)

log "Création du bundle…"
java -jar "$BUNDLETOOL" build-bundle --modules="$OUT/base.zip" --output="$AAB"

log "Signature (jarsigner, clé d'upload Play)…"
jarsigner -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" \
  -sigalg SHA256withRSA -digestalg SHA-256 "$AAB" app >/dev/null
jarsigner -verify "$AAB" | tail -1

log "Validation : génération d'un APK universel de contrôle…"
java -jar "$BUNDLETOOL" validate --bundle="$AAB" >/dev/null
java -jar "$BUNDLETOOL" build-apks --bundle="$AAB" --output="$OUT/check.apks" --mode=universal \
  --ks="$KEYSTORE" --ks-key-alias=app --ks-pass="pass:$KS_PASS" --key-pass="pass:$KS_PASS"
log "OK : $(pwd)/$AAB"
