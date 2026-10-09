# Schema: Wachalltag (Defect · Asset · Ack)

Stand: 9. August 2026  
Bezug: [FAHRPLAN-BEHOERDEN.md](FAHRPLAN-BEHOERDEN.md) Phase A

Vertragsentwurf für Webapp-Demo, späteren Server (`/api/v1/`) und Flutter-Client.
Kein Einsatz-/Patienten-/Vorgangsbezug.

## Prinzipien

1. **Defensives Parsen** — fehlende/falsche Felder ergeben Defaults, keinen Crash
   (Flutter: manuelle `fromJson`-Factories wie bei Checklisten; keine Freezed-/codegen-Abhängigkeit im Client)
2. **Append-only Historie** bei Statuswechseln und Quittierungen (Server später)
3. **Gleiche Feldnamen** in Webapp (`landing/app/data.js`) und Flutter-Modellen
4. **Enums als Strings** in JSON (`open`, `ready`, …) — stabil für API-Versionierung
5. **State** — `ChangeNotifier` + Screen-lokaler State (wie `HandoverState`); API-Methoden werfen `501`, bis der Server liefert
6. **Modul-Flags** — UI nur zeigen, wenn `station.modules.defects|assets == true`

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

### Endpoints (Server, eingefrorener Vertrag OpenAPI 1.4.0)

```
GET    /api/v1/defects/
GET    /api/v1/defects/{id}/          # Detail + events (max. 100) + attachments
POST   /api/v1/defects/
PATCH  /api/v1/defects/{id}/          # nur description, asset_ref, priority, owner, due_at
POST   /api/v1/defects/{id}/status/   # { "status": "…" } append-only
```

`PATCH /api/v1/defects/{id}/` ändert ausschließlich `description`, `asset_ref`,
`priority`, `owner` und `due_at`. `title` und `category` sind bei der Erzeugung
fest; mitgeschickt werden sie ignoriert und zählen nicht als Änderung. Ein Body
ohne mindestens ein änderbares Feld wird mit `422` beantwortet. Der Client
(`defectDetail`, `updateDefect`) setzt diese Regel um und sendet `title`/`category`
nie mit.

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
| `version` | int \| null | nein | Gebundene Übergabe-Revision; `null` bei Legacy-Quittungen (vor revisionsgebundener Quittierung) |

### Endpoints (Vertrag ≥ 1.4.0)

```
GET    /api/v1/handovers/{id}/acks/
POST   /api/v1/handovers/{id}/ack/    # { "version": <positive int> } — Pflicht
```

Die Quittung ist **revisionsgebunden** (S2): Der Client sendet im Body die
`version` der tatsächlich gelesenen Übergabe. Fehlt `version` oder ist sie keine
positive ganze Zahl (`null`, bool, String, Float, `0`, negativ), antwortet der
Server mit `422`. Stimmt die gesendete Revision nicht mehr mit der aktuellen
Server-Revision überein, antwortet er mit `409` und `error.code = "conflict"`.
Der Client lädt dann **nicht** automatisch nach und quittiert **nicht**
automatisch, sondern zeigt einen Neuladehinweis. `POST` ist idempotent pro
Benutzer *und* Revision; die Antwort (`200` bei Wiederholung, `201` bei
Neuanlage) enthält `version`. Der Client quittiert nie automatisch (kein
Auto-Retry) und zählt eine alte Quittung nicht als „von Ihnen quittiert“ für
eine neue Revision. Fehlt die Revision der Übergabe in der Antwort, ist die
Quittieraktion gesperrt (fail closed) statt eine Revision zu erraten.

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
| Flutter Modelle + Demo-API + UI | A–D + F-Felder + G Inventar; HTTP-Client verdrahtet |
| Server API | offen (Contract hier) |

## Abnahme

- [x] Feldnamen Webapp ↔ Dokument deckungsgleich
- [x] Flutter `fromJson` mit Unit-Tests für Alias/Müll-Eingaben
- [x] Flutter HTTP-Client für defects/assets/inventory/acks (404 = Modul aus)
- [ ] Server OpenAPI-Spiegel nach Freeze
