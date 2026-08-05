# Wachbuch Client (AGPL)

[![Flutter CI](https://github.com/darkspike1988/Wachbuch-Client/actions/workflows/ci.yml/badge.svg)](https://github.com/darkspike1988/Wachbuch-Client/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-green?logo=android)](https://developer.android.com/)
[![Platform: iOS](https://img.shields.io/badge/Platform-iOS-blue?logo=apple)](https://developer.apple.com/ios/)

---

## 📱 **Was ist der Wachbuch Client?**

Der **Wachbuch Client** ist die **offizielle Mobile-App** für das **[Rettungswache-Wachbuch](https://github.com/darkspike1988/Rettungswache-Wachbuch)** – eine selbstgehostete Webanwendung für die interne Organisation von Rettungswachen.

### 🎯 **Zweck der App**

Die App ermöglicht **Mitarbeitern von Rettungswachen** den **mobilen Zugriff** auf das Wachbuch-System:

- **Schichtübergaben** einsehen und erstellen
- **Wachenkalender** anzeigen
- **Kaffeekasse** verwalten
- **Tagesaufgaben** abhaken
- **Checklisten** abarbeiten
- **Chat-Nachrichten** lesen und schreiben

**Ohne** dass sensible Daten (Einsätze, Patienten, Alarmierungen) verarbeitet werden.

---

## 🏗️ **Technischer Stack**

| Komponente | Technologie | Version | Zweck |
|------------|-------------|---------|-------|
| **Framework** | Flutter | SDK ^3.8.0 | Cross-Plattform UI |
| **Sprache** | Dart | ^3.8.0 | Programmiersprache |
| **State Management** | SetState + Provider | - | Zustandverwaltung |
| **Lokale Speicherung** | Shared Preferences | ^2.5.3 | Einstellungen |
| **Sichere Speicherung** | Flutter Secure Storage | ^9.2.4 | Tokens, Keys |
| **HTTP-Client** | http | ^1.4.0 | API-Anfragen |
| **Lokalisierung** | intl | ^0.19.0 | Mehrsprachigkeit |
| **QR-Scanner** | mobile_scanner | ^7.4.0 | Server-QR-Code scannen |
| **Berechtigungen** | permission_handler | ^12.0.3 | Laufzeitberechtigungen |
| **Netzwerkstatus** | connectivity_plus | ^6.1.0 | Offline-Erkennung |
| **Standort** | geolocator | ^14.0.2 | Sonnenaufgang/-untergang |
| **Deep Links** | app_links | ^7.2.1 | wachbuch:// URLs |

---

## 🔗 **Verbindung zum Server**

### **Server-Kompatibilität**

| Server-Version | Client-Version | API-Version | Funktionen |
|----------------|----------------|-------------|------------|
| 0.15.0+ | 0.5.1+ | v1 | Demo-Modus, Kaffeekasse-Zahlungshinweise, App-Token-Härtung |
| 0.14.1+ | 0.5.0+ | v1 | API v1, App-Tokens, MFA |
| 0.14.0+ | 0.5.0+ | v1 | Deutsche Alias-Pfade, Checklisten-Modul |

### **API-Dokumentation**

- **Server-Repository**: [Rettungswache-Wachbuch](https://github.com/darkspike1988/Rettungswache-Wachbuch)
- **API-Spezifikation**: [docs/API.md](https://github.com/darkspike1988/Rettungswache-Wachbuch/blob/main/docs/API.md)
- **OpenAPI-Schema**: `/api/v1/openapi.yaml` (auf dem Server)

### **Authentifizierung**

Die App verwendet **Token-basierte Authentifizierung**:

1. **Benutzername & Passwort** (bei aktiviertem MFA: App-Token aus dem Web)
2. **Token wird lokal gespeichert** (Flutter Secure Storage)
3. **Token ist widerrufbar** (im Web-UI unter "Mein Konto → App-Tokens")

---

## 🚀 **Schnellstart**

### **Voraussetzungen**

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Stable Channel)
- [Android Studio](https://developer.android.com/studio) (für Android)
- [Xcode](https://developer.apple.com/xcode/) (für iOS, nur macOS)
- Java 17+ (für Android-Builds)

### **Projekt klonen und starten**

```bash
# Repository klonen
git clone https://github.com/darkspike1988/Wachbuch-Client.git
cd Wachbuch-Client

# Abhängigkeiten installieren
flutter pub get

# Code-Qualität prüfen
flutter analyze

# Tests ausführen
flutter test

# App starten (für Entwicklung)
flutter run
```

---

## 📱 **Build-Anleitungen**

### **Android**

#### **Interne Testversion (parallel zur Produktions-App installierbar)**

```bash
# APK für alle ABIs bauen
flutter build apk --release --flavor internal --split-per-abi

# APK installieren
adb install build/app/outputs/flutter-apk/app-internal-arm64-v8a-release.apk
```

**Paket-ID**: `de.wachbuch.mobile.internal`

#### **Produktionsversion**

1. **Signing-Key vorbereiten**:
   ```bash
   cp android/key.properties.example android/key.properties
   # key.properties mit eigenen Keys füllen
   ```

2. **AppBundle bauen**:
   ```bash
   BUILD_NAME=0.5.2 BUILD_NUMBER=11 bash scripts/build-aab.sh
   ```

3. **APKs bauen**:
   ```bash
   flutter build apk --release --flavor production --split-per-abi
   ```

**Paket-ID**: `de.wachbuch.mobile`

### **iOS**

#### **Simulator-Build**

```bash
flutter pub get
flutter build ios --simulator --debug
```

#### **Release-Build (ohne Signierung)**

```bash
flutter build ios --release --no-codesign
```

#### **TestFlight-Build**

Siehe [docs/IOS-TESTFLIGHT.md](docs/IOS-TESTFLIGHT.md) für die vollständige Anleitung.

---

## 🎨 **App-Funktionen**

### **Startflow**

1. **Server-Adresse eingeben** oder **QR-Code scannen**
2. **Benutzername & Passwort** eingeben
3. **Anmelden** (bei MFA: App-Token aus dem Web-UI verwenden)

### **Hauptfunktionen**

| Funktion | Beschreibung |
|----------|--------------|
| **Übergaben** | Aktive Übergaben anzeigen, filtern, Details einsehen |
| **Kalender** | Wachenkalender mit Terminen |
| **Kaffeekasse** | Kassenstand einsehen, Buchungen erstellen |
| **Checklisten** | Checklisten anzeigen und abhaken |
| **Chat** | Interne Wachenkommunikation (E2EE) |
| **Profil** | Benutzerinformationen, App-Tokens verwalten |

### **Design & UX**

- **Material Design 3** (MD3)
- **Responsives Layout** (Smartphone & Tablet)
- **Automatisches Tag/Nacht-Design** (basierend auf Sonnenstand)
- **Bottom Navigation** (Smartphone) / **Navigation Rail** (Tablet)
- **Offline-Hinweis** für gelesene Seiten

---

## 🌍 **Mehrsprachigkeit**

Die App unterstützt:

- **Deutsch** (Standard)
- **Englisch** (vollständig)

**Weitere Sprachen** können durch Übersetzungsdateien in `lib/l10n/` hinzugefügt werden.

---

## 🔒 **Sicherheit**

### **Daten auf dem Gerät**

- **App-Tokens**: Gespeichert in Flutter Secure Storage (Keychain/Keystore)
- **Chat-Nachrichten**: End-to-End-verschlüsselt (AES-256-GCM + ECDH P-256)
- **Standortdaten**: Nur während der App-Nutzung abgefragt, verlassen das Gerät nicht

### **Netzwerk**

- **HTTPS nur**: Alle Verbindungen zum Server sind TLS-verschlüsselt
- **Zertifikatsprüfung**: Standardmäßige Zertifikatsvalidierung
- **Keine Daten an Dritte**: Keine Telemetrie, Analytics oder Tracking

---

## 📦 **Projektstruktur**

```
lib/
├── api/                  # API-Client & Modelle
│   ├── client.dart       # HTTP-Client für Server-Kommunikation
│   ├── models/           # Datenmodelle (JSON-Serialisierung)
│   └── server_address.dart # Server-Adressenverwaltung
├── auth/                 # Authentifizierung
│   └── session_store.dart # Token-Speicherung
├── l10n/                # Lokalisierung
│   └── generated/        # Automatisch generierte Übersetzungen
├── screens/             # Bildschirme (UI)
│   ├── home_shell.dart   # Hauptnavigation
│   ├── login_screen.dart # Login-Bildschirm
│   ├── server_setup_screen.dart # Server-Konfiguration
│   └── ...              # Weitere Bildschirme
├── services/            # Dienstprogramme
│   ├── connectivity_service.dart # Netzwerkstatus
│   └── ...              # Weitere Services
├── state/               # Zustandverwaltung
│   ├── auth_state.dart   # Authentifizierungszustand
│   └── handover_state.dart # Übergaben-Zustand
├── theme/               # Design & Stile
│   ├── app_theme.dart    # App-Theme
│   └── solar_theme.dart  # Sonnenstand-basiertes Theme
└── main.dart            # App-Einstiegspunkt
```

---

## 🤝 **Mitwirken**

Beiträge sind willkommen! Bitte beachte:

1. **Issue erstellen**: Vor dem Entwickeln ein Issue erstellen
2. **Fork erstellen**: Eigene Kopie des Repositories
3. **Branch-Naming**: `feature/xxx`, `fix/xxx`, `docs/xxx`
4. **Code-Qualität**: `flutter analyze` muss erfolgreich sein
5. **Tests**: `flutter test` muss erfolgreich sein

### **Code-Standards**

- **Dart**: `flutter_lints` + `very_good_analysis`
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/)
- **Pull Requests**: Klare Beschreibung, Referenz zum Issue

---

## 📚 **Dokumentation**

| Dokument | Beschreibung |
|----------|--------------|
| [Android Installationsanleitung](docs/INSTALL-ANDROID.md) | APK-Installation auf Android-Geräten |
| [Play Store Veröffentlichung](docs/PLAY-STORE.md) | Anleitung für Google Play Store |
| [iOS TestFlight](docs/IOS-TESTFLIGHT.md) | TestFlight-Bereitstellung |
| [Server-Integration](docs/SERVER.md) | Verbindung zum Wachbuch-Server |
| [Marktanalyse](docs/MARKET-RESEARCH.md) | Analyse ähnlicher Apps |
| [Design-System](docs/DESIGN-SYSTEM.md) | UI/UX-Richtlinien |
| [Roadmap](ROADMAP.md) | Geplante Funktionen |

---

## 📄 **Lizenz**

**Copyright (C) 2026 Darkspike1988**

Veröffentlicht unter der **GNU Affero General Public License v3.0 oder später**.

> ⚠️ **Wichtig**: Wer eine geänderte Fassung als Netzwerkdienst betreibt, muss den Benutzern den zugehörigen Quellcode anbieten (AGPL §13).

---

## 🆘 **Support**

- **Issues**: [GitHub Issues](https://github.com/darkspike1988/Wachbuch-Client/issues)
- **Dokumentation**: [Docs-Verzeichnis](docs/)
- **Discussions**: [GitHub Discussions](https://github.com/darkspike1988/Wachbuch-Client/discussions)

---

## 🔗 **Verwandte Projekte**

- **[Rettungswache-Wachbuch](https://github.com/darkspike1988/Rettungswache-Wachbuch)** – Der Server (Django/PostgreSQL)
- **[Docker Image](https://github.com/darkspike1988/Rettungswache-Wachbuch/pkgs/container/rettungswache-wachbuch)** – Vorgebaute Server-Container

---

*Letzte Aktualisierung: August 2026 | App-Version: 0.5.1+9*