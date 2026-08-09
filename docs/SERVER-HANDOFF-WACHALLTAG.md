# Server-Handoff: Wachalltag-API (Welle 2 / Phase 1)

Stand: 9. August 2026  
Ziel-Repo: https://github.com/darkspike1988/Rettungswache-Wachbuch  
Contract: [openapi-wachalltag.yaml](openapi-wachalltag.yaml) · [SCHEMA-WACHALLTAG.md](SCHEMA-WACHALLTAG.md)

Der Flutter-Client ist bereits gegen diese Pfade verdrahtet
(`lib/api/client.dart`, Pfadkonstanten in `lib/api/wachalltag_paths.dart`).
Fehlende Module sollen **404** (nicht 500) liefern; der Client mappt das auf
„Modul nicht verfügbar“.

## Muss in Phase 1

### 1. Modul-Flags in `GET /api/v1/me/`

Unter `membership.station.modules`:

```json
{
  "defects": true,
  "assets": true,
  "inventory": false
}
```

`inventory` darf in Phase 1 `false` bleiben.

### 2. Defects

| Methode | Pfad | Bemerkung |
| --- | --- | --- |
| GET | `/api/v1/defects/` | Liste, ideal `{ "results": [ … ] }` |
| GET | `/api/v1/defects/{id}/` | Detail |
| POST | `/api/v1/defects/` | Anlegen |
| PATCH | `/api/v1/defects/{id}/` | erlaubte Felder |
| POST | `/api/v1/defects/{id}/status/` | Body `{ "status": "open\|in_progress\|waiting\|done" }`, append-only Audit |

### 3. Assets

| Methode | Pfad | Bemerkung |
| --- | --- | --- |
| GET | `/api/v1/assets/` | `{ "results": [ … ] }` |
| POST | `/api/v1/assets/{id}/status/` | `{ "status": "ready\|limited\|oob\|workshop", "note": "…" }` |

### 4. Handover-Quittierung

| Methode | Pfad | Bemerkung |
| --- | --- | --- |
| GET | `/api/v1/handovers/{id}/acks/` | Liste |
| POST | `/api/v1/handovers/{id}/ack/` | idempotent pro User; Body `{}` ok |

## Fehlerverhalten

| Situation | Status |
| --- | --- |
| Modul global aus / nicht implementiert | **404** (Client zeigt UI nicht / leert Board) |
| Nicht angemeldet | 401 |
| Keine Berechtigung | 403 |
| Unbekannte ID | 404 mit klarer `error`-Message |
| Validierungsfehler | 400 |

Auth unverändert: `Authorization: Token <wb_…>`.

## Rollen (Minimalvorschlag)

| Aktion | Mitglied | Schichtleitung / Admin |
| --- | --- | --- |
| Mangel lesen | ja | ja |
| Mangel anlegen / Owner setzen | ja | ja |
| Status → `done` | optional nein | ja |
| Asset-Status setzen | optional nein | ja |
| Übergabe quittieren | ja | ja |

## Phase 3 (nach Kern) — Attachments

Contract bereits im OpenAPI-Draft:

| Methode | Pfad | Bemerkung |
| --- | --- | --- |
| GET | `/api/v1/defects/{id}/attachments/` | Liste Metadaten |
| POST | `/api/v1/defects/{id}/attachments/` | JSON-Metadaten und/oder multipart `file` |

Client hat Demo-Platzhalter + HTTP-Metadaten-POST; Multipart/Kamera folgt nach Server.

## Nicht in Phase 1

- Attachments / Foto-Upload (siehe Phase 3 oben)  
- Inventory Checkout (Client fertig; Server Audit)  
- Checklist-Intervalle serverseitig  
- Push  

## Abnahmecheckliste (Staging)

```bash
# Discovery
curl -sS "$BASE/api/v1/" | jq .

# Me + Module
curl -sS -H "Authorization: Token $TOKEN" "$BASE/api/v1/me/" | jq '.membership.station.modules'

# Defects
curl -sS -H "Authorization: Token $TOKEN" "$BASE/api/v1/defects/" | jq .
curl -sS -H "Authorization: Token $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"Testmangel","priority":"normal","status":"open"}' \
  "$BASE/api/v1/defects/" | jq .

# Assets
curl -sS -H "Authorization: Token $TOKEN" "$BASE/api/v1/assets/" | jq .

# Ack (HANDVER_ID setzen)
curl -sS -H "Authorization: Token $TOKEN" -H "Content-Type: application/json" \
  -d '{}' "$BASE/api/v1/handovers/$HANDOVER_ID/ack/" | jq .
curl -sS -H "Authorization: Token $TOKEN" "$BASE/api/v1/handovers/$HANDOVER_ID/acks/" | jq .
```

## Spiegelung

1. `openapi-wachalltag.yaml` nach `docs/` im Server-Repo kopieren.  
2. In Server-`docs/API.md` verlinken.  
3. Nach Implementierung Client-Version in `SERVER.md` / README-Paarung ergänzen.
