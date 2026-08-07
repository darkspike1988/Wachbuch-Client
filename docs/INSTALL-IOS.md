# iOS installieren und intern testen (Sideloading)

Stand: 6. August 2026

Für den offiziellen TestFlight-Weg gilt zusätzlich
[`IOS-TESTFLIGHT.md`](IOS-TESTFLIGHT.md). Diese Anleitung beschreibt das
Sideloading auf eigene Geräte **ohne** App Store und ohne kostenpflichtigen
Apple-Developer-Account. Der Fortschritt steht in
[`ROADMAP.md`](../ROADMAP.md).

## Varianten

| Variante | Bundle-ID | Verwendung |
| --- | --- | --- |
| Simulator | `de.wachbuch.wachbuchMobile` | Entwicklung und UI-Tests am Mac |
| Sideloading (Xcode, kostenlose Apple-ID) | `de.wachbuch.wachbuchMobile` | Internes Testen auf eigenen iPhones/iPads |
| TestFlight / App Store | `de.wachbuch.wachbuchMobile` | siehe `IOS-TESTFLIGHT.md` |

Deep-Link-Schema ist in allen Varianten `wachbuch://`
(siehe `ios/Runner/Info.plist`, `CFBundleURLSchemes`).

## Voraussetzungen

1. macOS mit Xcode (inkl. iOS-Simulator-Runtime)
2. aktuelles Flutter Stable
3. kostenlose Apple-ID (für Sideloading auf echte Geräte)
4. laufender Wachbuch-Server mit `/api/v1/` und gültiger HTTPS-Adresse
   (die App lehnt `http://` in Release-Builds ab)

## Simulator-Build

```bash
flutter pub get
flutter build ios --simulator --debug --no-codesign
```

Start direkt im Simulator (Gerät vorher booten, z. B. `xcrun simctl boot "iPhone 16"`):

```bash
flutter run -d <simulator-udid>
```

Der Simulator-Build benötigt **kein** Signing.

## Sideloading auf ein echtes Gerät (Xcode)

Apple erlaubt mit einer kostenlosen Apple-ID das Signieren und Installieren
auf eigenen Geräten („Personal Team“). Einschränkungen:

- App läuft maximal **7 Tage**, danach muss sie erneut installiert werden
- maximal 3 gleichzeitig signierte Apps pro Gerät
- die Bundle-ID darf noch nicht von einem anderen Team im App Store belegt sein

Schritte:

1. iPhone per Kabel verbinden und dem Gerät vertrauen.
2. Projekt öffnen: `open ios/Runner.xcworkspace`
3. Unter **Signing & Capabilities** das eigene Apple-ID-Team auswählen
   (Xcode → Settings → Accounts, falls noch kein Team vorhanden).
4. Falls die Bundle-ID `de.wachbuch.wachbuchMobile` im eigenen Team einen
   Konflikt meldet, für das Testgerät eine eigene Variante eintragen,
   z. B. `de.wachbuch.wachbuchMobile.<euer-name>`.
5. Schema **Runner** + das verbundene Gerät wählen → **Run** (▶).

Xcode signiert, installiert und startet die App. Danach in der App die
Server-Adresse des Wachbuch-Servers eintragen (oder QR-Code scannen).

## Release-IPA für AltStore/SideStore

Wer die App ohne dauerhaft angeschlossenes Gerät neu signieren möchte
(z. B. über AltStore/SideStore), erzeugt ein unsigniertes IPA und signiert
es im Sideloading-Tool nach:

```bash
flutter pub get
flutter build ipa --no-codesign
```

Das Ergebnis liegt unter `build/ios/ipa/` bzw. `build/ios/archive/`. Für den
Export mit Xcode: **Product → Archive** und danach **Distribute App →
Custom → Development** mit dem eigenen Team.

Hinweis: Ein mit kostenloser Apple-ID signiertes IPA verhält sich wie oben
beschrieben (7-Tage-Limit, erneutes Sideloading nötig).

## Checks vor dem Verteilen

```bash
flutter analyze
flutter test
flutter build ios --release --no-codesign   # signierfreier Kompilier-Check
```

## Bekannte Grenzen

- Push-Benachrichtigungen (Web-Push) sind eine Server-/Browser-Funktion; der
  iOS-Client erhält Push nur über die im Server dokumentierten Wege.
- Kamera-Zugriff wird nur für den QR-Scan der Server-Adresse verwendet
  (`NSCameraUsageDescription` in `Info.plist`).
- Standortzugriff ist optional und dient ausschließlich der lokalen
  Tag-/Nacht-Design-Berechnung (`NSLocationWhenInUseUsageDescription`).

## Deep-Link manuell testen

Die App registriert das Schema `wachbuch://` (siehe `Info.plist`).
Server-Verbindung lässt sich damit ohne Tippen setzen:

```bash
xcrun simctl openurl booted "wachbuch://connect?url=https%3A%2F%2Fwache.example.org"
```

Erlaubte Form: `wachbuch://connect?url=<kodiert>`, genau ein `url`-Parameter,
kein userinfo. Im Debug-Modus sind auch `http://`-Adressen (z. B.
`http://127.0.0.1:8000`) für lokale Server erlaubt.

## Fehlerbehebung

| Symptom | Ursache | Abhilfe |
| --- | --- | --- |
| Crash beim Start: `Could not find a storyboard named 'Main'` | vergifteter Xcode-Build-Cache nach abgebrochenem Build; `Main.storyboardc` fehlt im Bundle | `rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*` und neu bauen |
| App hängt lange im Start-Spinner | Debug-JIT auf dem Simulator ist beim ersten Start langsam | Geduld oder `flutter run -d <udid>` nutzen |
| `xcodebuild`: `iOS … is not installed` | passende Simulator-Runtime fehlt | `xcodebuild -downloadPlatform iOS` |
| `flutter build ios` meldet `CocoaPods not installed` | CocoaPods fehlt | `brew install cocoapods` |
