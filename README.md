# Compteurs liés — crochet-incr-mental

App Android pour incrémenter les lignes de crochet : compteurs liés, chrono, rappels sonores.
App WebView empaquetant la page « Compteurs liés ». 100 % hors ligne :
aucune permission réseau, la police Google Fonts a été retirée (repli sur la police système).

## Build
```bash
./install-sdk.sh   # une fois : SDK Android dans ~/Android/Sdk (~300 Mo, sans sudo)
./build.sh         # produit build/compteurs-lies.apk
```
Prérequis : JDK 17+ (`javac`, `keytool`), `curl`, `unzip`, `zip`.

Le keystore de signature est créé dans `~/.android/compteurs-lies.jks` (mot de passe
`KS_PASS`, défaut `compteurs-lies`). **Le conserver** : sans lui, impossible de publier une mise à
jour sans désinstaller l'app (et donc perdre les compteurs).

## Installation
- `adb install -r build/compteurs-lies.apk`, ou
- copier l'APK sur le téléphone et l'ouvrir (autoriser « sources inconnues »).

## Mise à jour de la page
Remplacer `assets/index.html`, incrémenter `versionCode` dans `AndroidManifest.xml`, relancer `./build.sh`.

## Rollback
Désinstaller l'app (les compteurs, stockés en local dans l'app, sont alors perdus) ou réinstaller
l'APK précédent signé avec le même keystore.

## AAB (Play Store)
```bash
./build-aab.sh     # produit build/compteurs-lies.aab, signé avec le même keystore
```
- Un AAB ne s'installe pas directement sur un téléphone : il est destiné à la Play Console.
- Le keystore sert de **clé d'upload** ; activer *Play App Signing* (Google garde la clé de distribution).
- Chaque nouvel envoi exige un `versionCode` supérieur dans `AndroidManifest.xml`.
- Test local : `java -jar ~/Android/Sdk/bundletool/bundletool-all-1.17.2.jar install-apks --apks=build/aab/check.apks`

## Installation et mises à jour avec Obtainium
1. Installer [Obtainium](https://github.com/ImranR98/Obtainium) sur le téléphone.
2. *Ajouter une application* → coller l'URL du dépôt GitHub → *Ajouter*.
3. Obtainium installe le dernier APK publié en release et propose les mises à jour.

## Publier une nouvelle version
1. Incrémenter `versionCode` **et** `versionName` dans `AndroidManifest.xml`, committer.
2. Publier :
   ```bash
   ./release.sh   # jeton lu dans ~/.config/compteurs-lies/github.env
   ```
   Le script reconstruit l'APK, pousse le tag `vX.Y` et crée la release avec l'APK attaché.
   Jeton : *fine-grained token* limité à ce dépôt, droit *Contents: Read and write*.

⚠️ Toujours signer avec le même keystore : sinon Obtainium/Android refuse la mise à jour.
