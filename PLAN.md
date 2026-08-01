# Umsetzungsplan: Review-Remediation Wachbuch

Stand: 2026-08-01  
Basis: Code-Review von `Rettungswache-Wachbuch` + leerem `Wachbuch-Client`

Hinweis: Schreibzugriff von diesem Agent auf `darkspike1988/Rettungswache-Wachbuch`
fehlt (`cursor[bot]` → 403). Die Server-Änderungen liegen deshalb unter `backend/`
in diesem Repo und sollen nach Freigabe der Cursor-GitHub-App zurück in das
Upstream-Repo synchronisiert werden.

---

## Phase A – Sicherheit & Trust

| ID | Punkt | Maßnahme | Status |
|---|---|---|---|
| A1 | Tailscale-Header-Spoofing | Header nur aus `TRUSTED_PROXY_CIDRS` | done |
| A2 | `/healthz/` offen | Nur Loopback/RFC1918/ULA | done |
| A3 | Trivy fehlt in CI | FS- und Image-Scan im Root-Workflow | done |
| A4 | Handover UPDATE zu breit | Spaltenweise UPDATE-Rechte, kein DELETE | done |

## Phase B – Fachliche Integrität

| ID | Punkt | Maßnahme | Status |
|---|---|---|---|
| B1 | Kein Korrekturpfad Übergabe | Versionierte Inhaltsbearbeitung | done |
| B2 | Kalender nur Create | Bearbeiten + Absage-Bestätigungsseite | done |
| B3 | Kaffee-Korrektur Race | `select_for_update` | done |
| B4 | Feeds nicht stationsbezogen | Optionale `FeedSource.station` | done |
| B5 | Keine Retention | `purge_expired_data` + RETENTION_* | done |
| B6 | `pending_count` global | Staff/Superuser ausgeschlossen | done |

## Phase C – UX & Konsistenz

| ID | Punkt | Maßnahme | Status |
|---|---|---|---|
| C1 | ASCII vs. Umlaute | Nutzertexte korrigiert | done |
| C2 | Feed-Beispiele lokal geprägt | Generische Test-Hosts; CSV-URL nicht hardcodiert | done |
| C3 | Revision ohne Inhalt | Snapshot in der Historie sichtbar | done |

## Phase D – Auth-Härtung

| ID | Punkt | Maßnahme | Status |
|---|---|---|---|
| D1 | Keine MFA | Optionale TOTP (`pyotp`) unter `/sicherheit/` | done |

## Phase E – Client-Strategie

| ID | Punkt | Maßnahme | Status |
|---|---|---|---|
| E1 | Leerer Client | PWA unter `client/` | done |
| E2 | Kein API-Vertrag | `/api/v1/me|dashboard|handovers/` | done |

## Phase F – Ops & Doku

| ID | Punkt | Maßnahme | Status |
|---|---|---|---|
| F1 | Go-live / Architektur | Doku aktualisiert | done |
| F2 | Changelog | Review-Remediation dokumentiert | done |
| F3 | Tests | 46 Tests grün | done |

---

## Nicht im Code lösbar (operativ, bleibt Hard Gate)

- Cursor-GitHub-App für `Rettungswache-Wachbuch` freigeben (Schreibzugriff)
- Multi-Repo-Environment im Cursor-Dashboard
- Organisatorische Freigaben: DSFA, Mitbestimmung, Offsite-Backup, ASVS-L2
- Formale Rollenmatrix mit dem Wachenteam durchspielen
