# Architektur

## Ueberblick

Das Wachbuch ist ein modularer Monolith aus Django und PostgreSQL. Webprozess,
Feed-Worker, Migrationen und Backup verwenden dasselbe Repository, aber getrennte
Container und Datenbankrollen.

```text
Browser
  |
TLS-Reverse-Proxy oder Tailscale Serve
  |
127.0.0.1:8090
  |
Django/Gunicorn -------- Feed-Worker -------- freigegebene HTTPS-Quellen
  |                            |
  +--------- PostgreSQL ------+
```

## Vertrauensgrenzen

- Docker bindet den Webport standardmaessig nur an Host-Loopback.
- Tailscale-Identitaetsheader werden nur bei explizitem
  `TRUST_TAILSCALE_HEADERS=true` **und** nur von Adressen in
  `TRUSTED_PROXY_CIDRS` (Standard: Loopback) ausgewertet.
- `/healthz/` antwortet nur aus Loopback, Link-Local, RFC1918 oder ULA.
- Web, Feed-Worker und Backup erreichen PostgreSQL ueber getrennte interne
  Netze. Der Worker hat keinen TCP-Pfad zum Webcontainer.
- Ein kurzlebiger `migrate`-Container besitzt die Datenbank-Owner-Rechte. Der
  dauerhafte Webprozess kennt ausschliesslich das eingeschraenkte App-Konto.
- Die Datenbank verhindert Updates und Loeschungen an Audit-Ereignissen,
  Kassenbuchungen und Uebergaberevisionen. Fuer Uebergaben sind DELETE und
  UPDATE auf Stammdatenfelder (`author_id`, `station_id`, `created_at`) entzogen.
- Feed-Hosts brauchen eine explizite Allowlist. Private Ziel-IP-Adressen,
  Redirects, andere Ports und uebergrosse Antworten werden abgewiesen.
- Optionale TOTP-MFA schuetzt die Passwort-Anmeldung. JSON-API unter `/api/v1/`
  nutzt dieselbe Session- und Rollenpruefung wie die HTML-Oberflaeche.

## Datenmodell

- `Station`, `Membership`: Wachen, Modulschalter, Rollen und Freigaben
- `HandoverEntry`, `HandoverRevision`: Arbeitsstand und unveraenderte Revisionen
  (Inhalt und Status versioniert)
- `CalendarEvent`: Wachen-, kein Dienstplankalender; Soft-Cancel via `cancelled_at`
- `BirthdayPreference`: freiwillig, nur Tag und Monat
- `CoffeeEntry`: append-only Buchungen in Cent und Korrekturbezug
- `FeedSource`, `FeedItem`: optionale externe Meldungen, Quelle optional je Station
- `TotpDevice`: optionale TOTP-Geheimnisse fuer Passwort-Login
- `AuditEvent`: Akteur, Aktion, Objekt und Zeitpunkt ohne Freitextkopien

## Authentifizierung

Im Standardmodus authentifiziert Django lokale Benutzer. Der Befehl
`grant_station_admin` verbindet einen Superuser mit einer Wache. Optional setzt
Tailscale Serve Identitaetsheader. Das konfigurierte Tailscale-Administratorkonto
wird beim ersten Zugriff der Standardwache zugeordnet; weitere Konten warten auf
eine Freigabe unter `/team/`.

## Wiederherstellung

Der Backup-Container schreibt taeglich PostgreSQL-Custom-Dumps in `./backups`
und behaelt sieben Tage. Das Verzeichnis gehoert nicht zum Docker-Build und wird
nicht von Git erfasst. Ein Restore-Test laeuft mit:

```bash
docker compose exec -T backup /bin/sh /backup/restore-test.sh
```

Lokale Dumps sind kein Offsite-Backup. Betreiber muessen Verschluesselung,
externes Ziel, RPO, RTO und regelmaessige Restore-Tests selbst festlegen.
