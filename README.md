# Wachbuch Client (AGPL)

Open-Source-Begleit-App für das selbst gehostete **[Wachbuch](https://github.com/darkspike1988/Rettungswache-Wachbuch)** auf iOS und Android.

| | |
| --- | --- |
| **Client** | https://github.com/darkspike1988/Wachbuch-Client |
| **Server** | https://github.com/darkspike1988/Rettungswache-Wachbuch |
| **Lizenz** | AGPL-3.0-or-later |
| **API** | `/api/v1/` · Token-Auth |
| **App-Version** | `0.6.0+10` |
| **Produktiv-Paarung** | Server `0.16.x` |
| **E2E-Abnahme** | [docs/E2E-WACHALLTAG.md](docs/E2E-WACHALLTAG.md) |
| **Roadmap** | [ROADMAP.md](ROADMAP.md) |

## Quelle der Wahrheit

Dieses Repository ist die **kanonische Quelle** für den Flutter-/iOS-/Android-Client. Der historische Ordner `clients/wachbuch-mobile/` im Server-Repository darf diesen Stand nicht überschreiben.

## Was 0.6.x kann

- Serveradresse oder QR verbinden; App-Token sicher in Keychain/Keystore speichern
- strukturierter API-Fehlervertrag mit `code`, `message` und `correlation_id`
- MFA-Fehler `mfa_required` und `mfa_setup_required` sauber behandeln
- Übergaben suchen/filtern, Details öffnen und pro Benutzer quittieren
- Übergabe direkt als echten Mangel übernehmen
- Mängel anlegen, priorisieren, zuordnen, terminieren und Status ändern
- authentifizierte Mängelfotos aus Kamera/Mediathek hoch- und herunterladen
- Foto-Schutz: JPEG/PNG/WebP, 2 MiB je Datei; Server begrenzt zusätzlich Anzahl/Gesamtmenge
- Fahrzeug-/Gerätestatus anzeigen und bei berechtigter Rolle ändern
- Schlüssel-/Poolgeräte ausgeben und zurückgeben
- wiederkehrende Checklisten mit täglicher/wöchentlicher/monatlicher Fälligkeit
- Auswertung für offene/überfällige Mängel, Checks, Einsatzklarquote, Pools und Quittierungen
- token- und servergebundener verschlüsselter Offline-Lesecache
- Offline-Fallback nur bei echten Netzwerkfehlern; 401/403 werden nie durch Cache verdeckt
- Demo-Profile für Rettungsdienst, Feuerwehr, Freiwillige Feuerwehr und Polizei
- Phone: Bottom-Navigation · Tablet: NavigationRail + Grid
- Material Design 3, Dark/Light und große Textskalierung
- Deutsch/Englisch für produktive Wachalltag-Oberflächen

## Produktgrenze

Wachbuch ist ein Werkzeug für den **Stations-/Wachalltag**. Nicht Teil des Modells sind insbesondere Patienten-, ePCR-, Einsatz-, Alarmierungs-, ELS-, Personalakten- oder vergleichbare sensible Fachdaten.

## Landingpage & Web-Demo

```bash
cd landing && python3 -m http.server 4173
# Landing → http://127.0.0.1:4173/
# Webapp  → http://127.0.0.1:4173/app/
```

Die Demo dient als Produkt-/UX-Vorschau. Die entsprechenden Kernfunktionen Mängel, Geräte, Inventar, Quittierungen, wiederkehrende Checks, Fotos und Auswertung besitzen in `0.6.x` reale Server-Endpunkte.

## Lokaler Start

```bash
git clone https://github.com/darkspike1988/Wachbuch-Client.git
cd Wachbuch-Client
flutter pub get
flutter test
flutter run --flavor internal
```

Auf iOS:

```bash
flutter pub get
flutter build ios --simulator --debug
```

## Android Internal

Die interne Variante besitzt die separate Paket-ID `de.wachbuch.mobile.internal` und kann parallel zur Produktions-App installiert werden:

```bash
./scripts/build-apk.sh
```

## Android Production

Ein Produktionsbuild benötigt einen eigenen Upload-Key und fällt niemals auf einen Debug-Key zurück:

```bash
cp android/key.properties.example android/key.properties
BUILD_NAME=0.6.0 BUILD_NUMBER=10 bash scripts/build-aab.sh
```

Der Release-Workflow erzeugt zusätzlich Hashes, Zertifikatsberichte, Obfuskationssymbole und eine CycloneDX-SBOM.

## Server-Kopplung

Der Vertrag liegt im Server-Repository unter `docs/API.md`, `docs/CLIENT.md` und `docs/openapi.yaml`. Die Kopplung erfolgt ausschließlich über den versionierten API-Vertrag – nicht durch Kopieren eines Client-Quellbaums in das Server-Repository.

## Qualitätsgates

Vor Freigabe müssen mindestens bestehen:

- `flutter analyze`
- vollständige Flutter-Tests
- Android Internal APKs
- Production-AAB ohne Publishing-Credentials
- Android Lint
- Berechtigungs-/Signatur-/SDK-/Größen-Gates
- SBOM-Erzeugung
- iOS Simulator/Release-Build ohne Signierung
- Dependency-Security

Siehe zusätzlich [docs/E2E-WACHALLTAG.md](docs/E2E-WACHALLTAG.md), [docs/INSTALL-ANDROID.md](docs/INSTALL-ANDROID.md), [docs/PLAY-STORE.md](docs/PLAY-STORE.md) und [docs/IOS-TESTFLIGHT.md](docs/IOS-TESTFLIGHT.md).

## Rechtliches

AGPL-3.0-or-later – siehe `LICENSE`.
