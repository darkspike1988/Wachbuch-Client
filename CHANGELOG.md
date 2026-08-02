# Changelog

Alle wesentlichen Änderungen an Wachbuch Mobile werden hier dokumentiert.

## 0.3.0 – 2026-08-02

### Neu

- Responsives Material-3-Layout für Smartphone und Tablet durch Regressionstests abgesichert.
- Automatischer Wechsel zwischen hellem und dunklem Design anhand lokal berechnetem Sonnenaufgang und Sonnenuntergang.
- Ungefährer Vordergrundstandort wird ausschließlich auf dem Gerät verarbeitet; keine externe Wetter- oder Standort-API.
- Fallback auf das Systemdesign, wenn Standortdienste deaktiviert oder die Berechtigung verweigert sind.
- Automatische Neuberechnung beim nächsten Sonnenwechsel und nach Rückkehr in die App.
- Vollständige Deep-Link-Unterstützung für `wachbuch://connect?url=…` unter Android und iOS.

### Sicherheit

- Ein Serverwechsel über Deep-Link löscht den alten App-Token, bevor die neue Adresse übernommen wird.
- Release-Builds lehnen unsichere HTTP-Server ab; HTTP bleibt nur in Debug-Builds explizit möglich.
- Temporäre und langlebige HTTP-Clients werden deterministisch geschlossen.

## 0.2.1 – 2026-08-02

### Geändert

- Flutter-Projekt vollständig in das eigenständige Client-Repository übernommen.
- API-Aufrufe erhalten ein konfigurierbares Zeitlimit von standardmäßig 20 Sekunden.
- Verständliche Meldungen für Netzwerkfehler, Zeitüberschreitungen, Reverse-Proxy-Fehler und ungültige Serverantworten.
- Lifecycle-Race behoben: späte API-Antworten lösen nach dem Schließen eines Screens kein `setState()` mehr aus.
- QR- und Serveradressen lehnen fremde Schemes, unvollständige Wachbuch-Links und beschädigte JSON-Payloads sauber ab.

### Tests

- API-Vertrag: Discovery, Token-Anmeldung, Auth-Header und Fehlerpfade.
- Secure Storage und Shared Preferences.
- Startflow, Formvalidierung und responsive Hauptnavigation.
- Regressionstest für späte API-Fehler nach Widget-Dispose.

### Android

- Installierbare Sideload-APK für Android 7.0 und neuer.
- Release-Build bleibt für lokale/CI-Verteilung mit Debug-Key signiert; Play-Store-Veröffentlichung benötigt einen eigenen Upload-Key.
