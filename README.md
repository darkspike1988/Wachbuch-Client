# Wachbuch-Client

Plattformübergreifender mobiler Client (iOS und Android) für den
[Rettungswache-Wachbuch](https://github.com/Darkspike1988/Rettungswache-Wachbuch)-Server.

Umgesetzt mit [Expo](https://expo.dev) (React Native + TypeScript), damit eine
einzige Codebasis auf iOS und Android läuft (und im Browser getestet werden kann).

## Voraussetzungen

- Node.js 20+ (getestet mit Node 22) und npm
- Der Wachbuch-Server muss laufen und erreichbar sein (Standard: `http://127.0.0.1:8090`)

## Installation

```bash
npm install
```

## Starten

```bash
npm run web        # Browser (Entwicklung/Test)
npm run android    # Android-Emulator oder verbundenes Gerät
npm run ios        # iOS-Simulator (nur auf macOS)
```

Der Expo Dev Server zeigt einen QR-Code; mit der **Expo Go** App kann die App
ohne eigenen Native-Build direkt auf einem iOS- oder Android-Gerät geöffnet
werden.

## Backend-Adresse konfigurieren

Die App liest die Server-Basis-URL aus `EXPO_PUBLIC_API_URL` (Standard
`http://127.0.0.1:8090`). Je nach Zielplattform:

- Web / iOS-Simulator (gleicher Host): `http://127.0.0.1:8090`
- Android-Emulator: `http://10.0.2.2:8090`
- Physisches Gerät: `http://<LAN-IP-des-Servers>:8090`

```bash
EXPO_PUBLIC_API_URL=http://10.0.2.2:8090 npm run android
```

## Funktionsumfang

Aktueller Stand: Startbildschirm, der die Verbindung zum Server über dessen
`/healthz/`-Endpunkt prüft und den Status anzeigt. Dies ist die Grundlage für
die weitere Anbindung an die Wachbuch-Funktionen (Übergaben, Kaffeekasse usw.),
sobald der Server eine entsprechende JSON-API bereitstellt.
