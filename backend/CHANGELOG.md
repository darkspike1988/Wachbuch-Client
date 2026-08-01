# Changelog

## Unreleased - Review-Remediation

- Tailscale-Header nur aus `TRUSTED_PROXY_CIDRS` (Standard: Loopback)
- `/healthz/` nur aus Loopback/RFC1918/ULA erreichbar
- DB: Übergabe-UPDATE nur auf fachlich erlaubte Spalten; kein DELETE
- Versionierte Inhaltsbearbeitung für Übergaben inkl. Snapshot-Historie
- Kalender: Bearbeiten und Absagen (Soft-Cancel)
- Kaffee-Korrektur mit `select_for_update`
- Feeds optional stationsbezogen
- Retention-Command `purge_expired_data` inkl. RETENTION_*-Settings
- Optionale TOTP-MFA für Passwort-Login
- JSON-API `/api/v1/me|dashboard|handovers/`
- Trivy-Scans in der CI; Nutzertexte mit Umlauten
- MFA-QR ohne Pillow (`segno`), um HIGH-CVEs in Pillow 11.3 zu vermeiden

## Unreleased - Open-Source-Basis

- portable Docker-Konfiguration ohne servergebundene Hosts und Datenbank-URLs
- sichere, stationsbezogene Einstellungsseite fuer Name und optionale Module
- lokaler Login und reproduzierbarer Erstadmin-Workflow ergaenzt
- Migrationen vom dauerhaften Webprozess getrennt
- Build-Kontext gegen Backups, Datenbanken und Bytecode abgesichert
- Adminzugriff auf fachliche und unveraenderliche Datensaetze eingeschraenkt
- GitHub-CI, Beitrags- und Sicherheitsrichtlinie vorbereitet
- Lizenz auf GNU AGPL v3 umgestellt

## 2026-07-28 - UI 0.2.0

- Dashboard auf aktive Uebergaben und die naechsten drei Termine reduziert
- globale Navigation auf Uebersicht, Uebergaben, Kalender und Mehr vereinfacht
- Schreibformulare auf eigene, lineare Seiten verschoben
- Uebergaben fachlich nach Dringlichkeit sortiert und Archiv getrennt
- Feedansicht nach Meldungen und Verkehr getrennt sowie paginiert
- Kassenbuch und Audit als semantische responsive Tabellen umgesetzt
- mobile Navigation, 768-Pixel-Tablet-Reflow und 44-Pixel-Touchziele eingefuehrt
- offene Designquellen und zehn verbindliche UX-Regeln dokumentiert

## 2026-07-28 - Tailnet-Pilot 0.1.0

- Django/PostgreSQL-Projektbasis und eigenes Git-Repository angelegt
- Uebergaben, Kalender, Geburtstage, Kaffeekasse, Teamrollen und Audit umgesetzt
- optionale offizielle RSS-/Verkehrsfeeds integriert
- Tailscale-Identitaet, Loopback-Bindung und getrennte Docker-Netze eingerichtet
- eingeschraenkte PostgreSQL-Rollen und Append-only-Rechte gesetzt
- taegliches lokales Backup, Restic-Offsite-Pfad und Restore-Test eingerichtet
- automatisierte Tests, Deployment-Checks und Trivy-Scans
- Pilot ausschliesslich im Tailnet bereitgestellt; oeffentliche Domain bleibt offline
