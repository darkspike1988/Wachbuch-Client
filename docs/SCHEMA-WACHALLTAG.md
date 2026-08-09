# Schema: Wachalltag (Defect · Asset · Ack · Inventory)

Stand: 9. August 2026  
Bezug: [FAHRPLAN-BEHOERDEN.md](FAHRPLAN-BEHOERDEN.md) (Welle 1) ·
[FAHRPLAN-PRODUKTIV.md](FAHRPLAN-PRODUKTIV.md) (Welle 2)  
OpenAPI: [openapi-wachalltag.yaml](openapi-wachalltag.yaml)  
Server-Handoff: [SERVER-HANDOFF-WACHALLTAG.md](SERVER-HANDOFF-WACHALLTAG.md)

Vertragsentwurf für Webapp-Demo, Server (`/api/v1/`) und Flutter-Client.
Kein Einsatz-/Patienten-/Vorgangsbezug.

## Prinzipien

1. **Defensives Parsen** — fehlende/falsche Felder ergeben Defaults, keinen Crash
   (Flutter: manuelle `fromJson`-Factories wie bei Checklisten; keine Freezed-/codegen-Abhängigkeit im Client)
2. **Append-only Historie** bei Statuswechseln und Quittierungen (Server später)
3. **Gleiche Feldnamen** in Webapp (`landing/app/data.js`) und Flutter-Modellen
4. **Enums als Strings** in JSON (`open`, `ready`, …) — stabil für API-Versionierung
5. **State** — `ChangeNotifier` + Screen-lokaler State (wie `HandoverState`)
6. **Modul-Flags** — UI nur zeigen, wenn `station.modules.defects|assets|inventory == true`
7. **404 = Modul aus** — fehlende optionale Module liefern 404 (nicht 500); Client blendet UI aus

## `defect`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `id` | int | ja | Stabiler Schlüssel |
| `title` | string | ja | Kurztext |
| `description` | string | nein | Details |
| `asset_ref` | string | nein | Freitext-Bezug (Fahrzeug/Gerät) |
| `priority` | `urgent` \| `important` \| `normal` | ja | Default `normal` |
| `status` | `open` \| `in_progress` \| `waiting` \| `done` | ja | Default `open` |
| `owner` | string | nein | Benutzername / Anzeige |
| `due_at` | ISO-8601 string \| null | nein | Frist |
| `due_label` | string | nein | Anzeigehilfe in Demos („heute 14:00“) |
| `category` | `vehicle` \| `material` \| `safety` \| `facility` \| `key` \| `device` \| `task` | nein | Default `task` |

### Geplante Endpoints (Server)

```
GET    /api/v1/defects/
GET    /api/v1/defects/{id}/
POST   /api/v1/defects/
PATCH  /api/v1/defects/{id}/          # nur erlaubte Felder
POST   /api/v1/defects/{id}/status/   # { "status": "…" } append-only
```

## `asset` (StationAsset)

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `id` | string | ja | z. B. `hlf-20` |
| `label` | string | ja | Anzeigename |
| `kind` | `vehicle` \| `device` \| `key` | ja | Default `device` |
| `status` | `ready` \| `limited` \| `oob` \| `workshop` | ja | Default `ready` |
| `note` | string | nein | Kurzhinweis |

### Geplante Endpoints

```
GET    /api/v1/assets/
POST   /api/v1/assets/{id}/status/   # { "status": "…", "note": "…" }
```

## `handover_ack`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `handover_id` | int | ja | Bezug Übergabe |
| `by` | string | ja | Benutzer |
| `at` | ISO-8601 | ja | Zeitstempel |

### Geplante Endpoints

```
GET    /api/v1/handovers/{id}/acks/
POST   /api/v1/handovers/{id}/ack/    # idempotent pro User
```

## `inventory` (Schlüssel / Pool)

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `id` | string | ja | Stabiler Schlüssel |
| `label` | string | ja | Anzeigename |
| `kind` | `key` \| `device` \| `vehicle` | ja | Default `device` |
| `holder` | string \| null | nein | Aktueller Benutzer |
| `since` | ISO-8601 \| null | nein | Checkout-Zeit |
| `since_label` | string | nein | Demo-Anzeigehilfe |
| `note` | string | nein | Hinweis (z. B. überfällig) |

### Geplante Endpoints

```
GET    /api/v1/inventory/
POST   /api/v1/inventory/{id}/checkout/
POST   /api/v1/inventory/{id}/checkin/
```

## Checklist-Erweiterung (Phase F)

| Feld | Typ | Beschreibung |
| --- | --- | --- |
| `interval` | `daily` \| `weekly` \| `monthly` \| `""` | Wiederkehr |
| `due_next` | ISO-8601 \| null | Nächste Fälligkeit |
| `overdue` | bool | Server- oder Client-Ableitung |

## Modul-Flags in `/me/` → `station.modules`

| Key | Bedeutung |
| --- | --- |
| `defects` | Mängel-Modul sichtbar |
| `assets` | Statusboard / Geräte sichtbar |
| `inventory` | Schlüssel- & Pool-Checkout sichtbar |

Demo-Profile setzen diese Flags auf `true`.

## Implementierungsstand

| Schicht | Status |
| --- | --- |
| Webapp Demo | A–D + E (objectURL) + F + G + I |
| Flutter Modelle + Demo-API + UI | verdrahtet inkl. createDefect / asset status |
| OpenAPI Draft | `openapi-wachalltag.yaml` (Welle 2 Phase 0) |
| Server API | offen — siehe SERVER-HANDOFF |

## Abnahme

- [x] Feldnamen Webapp ↔ Dokument deckungsgleich
- [x] Flutter `fromJson` mit Unit-Tests für Alias/Müll-Eingaben
- [x] Flutter HTTP-Client für defects/assets/inventory/acks (404 = Modul aus)
- [x] OpenAPI-Entwurf + Server-Handoff im Client-Repo
- [ ] Server OpenAPI-Spiegel + Phase-1-Endpoints
