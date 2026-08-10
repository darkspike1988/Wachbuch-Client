# iOS / TestFlight / App Store – Wachbuch 1.0

Stand: 10. August 2026

Der Flutter-Client verwendet die Bundle-ID `de.wachbuch.wachbuchMobile`. Seit 28. April 2026 müssen App-Store-Connect-Uploads mit **Xcode 26 oder neuer** und einem **iOS-26-SDK oder neuer** gebaut werden. Sowohl `iOS CI` als auch der TestFlight-Workflow prüfen diese Mindestversionen explizit.

Der verbindliche Abnahmeplan liegt in [`STORE-RELEASE-1.0.md`](STORE-RELEASE-1.0.md).

## Voraussetzungen

- Apple Developer Program aktiv
- Explicit App ID `de.wachbuch.wachbuchMobile`
- App-Eintrag in App Store Connect mit derselben Bundle-ID
- iOS Distribution-Zertifikat
- App-Store-Provisioning-Profile
- App Store Connect API Key
- Xcode 26+ / iOS SDK 26+
- aktuelles Flutter Stable

## Lokaler Simulator-/Release-Check

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build ios --simulator --debug
flutter build ios --release --no-codesign
```

Der unsigned Build ist nur ein technischer Check und nicht für App Store/TestFlight installierbar.

## GitHub Actions – iOS CI

`.github/workflows/ios.yml` läuft bei Pull Requests und Pushes auf `main` und prüft:

1. Xcode 26+ und iOS SDK 26+,
2. Flutter-/Dependency-Auflösung,
3. iOS-Simulator-Build,
4. unsigned iOS-Release-Build,
5. Produktions-Bundle-ID,
6. `ITSAppUsesNonExemptEncryption=false`,
7. Syntax aller im finalen App-Bundle vorhandenen `PrivacyInfo.xcprivacy`-Dateien,
8. Packaging des unsigned Prüfartefakts.

## Geschützter TestFlight-/App-Store-Upload

Der manuelle Workflow `.github/workflows/testflight.yml` verwendet das GitHub Environment `testflight`. Required Reviewer aktivieren.

Secrets:

| Secret | Inhalt |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_KEY_ID` | Key ID des App-Store-Connect-API-Schlüssels |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID des API-Schlüssels |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | Base64-kodierte `.p8`-Datei |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-kodierte `.p12`-Datei |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Passwort der `.p12`-Datei |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-kodiertes App-Store-Profil |
| `IOS_KEYCHAIN_PASSWORD` | starkes temporäres CI-Keychain-Passwort |

Beispiel zum Kodieren unter macOS:

```bash
base64 -i AuthKey_ABC123XYZ.p8 | pbcopy
base64 -i Wachbuch_Distribution.p12 | pbcopy
base64 -i Wachbuch_AppStore.mobileprovision | pbcopy
```

Die geheimen Dateien niemals committen.

## Was der Workflow vor dem Upload erzwingt

Für 1.0 werden standardmäßig `1.0.0` und Build `11` vorgeschlagen. Der Workflow:

1. läuft nur von `main`,
2. verlangt exakte Übereinstimmung mit `version: 1.0.0+11` in `pubspec.yaml`,
3. prüft Xcode/iOS-SDK,
4. validiert alle benötigten Secrets,
5. prüft, dass das Provisioning Profile zu `de.wachbuch.wachbuchMobile` gehört,
6. führt L10n, Analyze und die vollständigen Flutter-Tests aus,
7. archiviert signiert,
8. verifiziert archivierte Bundle-ID, Version, Build und Export-Compliance-Flag,
9. validiert gebündelte Privacy-Manifeste und Codesignatur,
10. exportiert die IPA,
11. führt `xcrun altool --validate-app` aus,
12. lädt erst danach über App Store Connect API Key hoch,
13. entfernt temporäre Signing-/API-Key-Dateien.

## Datenschutz / App Privacy

Öffentliche Datenschutzerklärung:

`https://github.com/darkspike1988/Wachbuch-Client/blob/main/docs/PRIVACY-POLICY.md`

Support:

`https://github.com/darkspike1988/Wachbuch-Client/blob/main/docs/SUPPORT.md`

Die wesentlichen Datenschutzinformationen sind zusätzlich bereits **vor der Anmeldung in der App erreichbar**.

App-Privacy-Angaben müssen den tatsächlichen Build und den echten Serverbetrieb widerspiegeln. Für 1.0 gilt nach aktuellem Code:

- keine Werbung / kein Tracking,
- keine externe Analytics-/Crash-Telemetrie,
- sichere lokale Speicherung von App-Token und Offline-Cache,
- Organisations-/Login-Daten gehen nur an den vom Nutzer eingerichteten Server,
- ausdrücklich ausgewählte Mängelfotos können an diesen Server übertragen werden,
- QR-Kamera lokal,
- ungefährer Standort nur lokal für Sonnenaufgang/-untergang.

Apple verlangt für Required-Reason-APIs und bestimmte SDKs korrekte Privacy-Manifeste. CI validiert die im finalen Bundle enthaltenen Manifeste; zusätzlich bleibt die Verarbeitung des hochgeladenen Builds in App Store Connect das verbindliche Store-Gate.

## Usage Descriptions

`Info.plist` enthält:

- `NSCameraUsageDescription`: QR-Scan + ausdrücklich ausgelöstes Mängelfoto
- `NSPhotoLibraryUsageDescription`: ausdrücklich ausgewähltes bestehendes Mängelfoto
- `NSLocationWhenInUseUsageDescription`: lokale Sonnenaufgang/-untergang-Berechnung
- `ITSAppUsesNonExemptEncryption=false`

Diese Texte müssen bei einer Funktionsänderung ebenfalls aktualisiert werden.

## App Review / Login

Apple verlangt für Apps mit Login grundsätzlich einen funktionsfähigen Review-Zugang. Der eingebaute Offline-Demo-Modus ist für schnelle Navigation vorhanden, ersetzt einen Demo-Account aber nur, wenn Apple dies akzeptiert.

Bevorzugt einen dedizierten HTTPS-Review-Server bereitstellen:

- keine realen Organisations-/Personendaten,
- dauerhaft gültiger Testnutzer oder App-Token,
- keine Einmal-MFA-Abhängigkeit,
- alle Kernmodule aktiviert,
- Zugangsdaten ausschließlich in App Store Connect hinterlegen.

Review-Text und Store-Metadaten: [`STORE-METADATA.md`](STORE-METADATA.md).

## 1.0-TestFlight-Reihenfolge

1. Release-PR vollständig grün mergen.
2. App-ID/App-Store-Connect-Eintrag und Signing-Assets anlegen.
3. GitHub-Environment/Secrets konfigurieren.
4. **Actions → TestFlight → Run workflow** auf `main`, Version `1.0.0`, Build `11`.
5. App Store Connect muss den Upload vollständig verarbeiten; Warnungen/Fehler kontrollieren.
6. TestFlight auf echtem iPhone und iPad testen.
7. Datenschutz, App Privacy, Altersfreigabe, Screenshots, Beschreibung und Review-Zugang vervollständigen.
8. Erst dann den ausgewählten Build zu App Review senden.
