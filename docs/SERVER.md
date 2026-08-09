# Server-Kopplung

Dieses Client-Repo gehört zu:

**https://github.com/darkspike1988/Rettungswache-Wachbuch**

| Client | Server |
| --- | --- |
| App 0.2.x | API `/api/v1/` ab Server **0.14.1** |
| Adresse / QR → Login | Discovery `GET /api/v1/` |
| User / Passwort | `POST /api/v1/token/` (Alias `/anmeldung/`) |
| MFA | App-Token unter `/konto/api/` |
| Station | nur aus `GET /api/v1/me/` / `uebersicht/` |
| Übergaben | `/handovers/` oder `/uebergaben/` |
| Kalender / Kasse / Checklisten | `/kalender/`, `/kaffeekasse/`, `/checklisten/` |
| Wachalltag (geplant) | `defects/`, `assets/`, `handovers/{id}/ack/`, `inventory/` |

Header: `Authorization: Token <wb_…>` (widerrufbar)

Ausführlich: [docs/API.md im Server](https://github.com/darkspike1988/Rettungswache-Wachbuch/blob/main/docs/API.md)

### Wachalltag-Contract (Welle 2)

- OpenAPI-Entwurf: [openapi-wachalltag.yaml](openapi-wachalltag.yaml)
- Handoff für Server-Implementierung: [SERVER-HANDOFF-WACHALLTAG.md](SERVER-HANDOFF-WACHALLTAG.md)
- Fahrplan: [FAHRPLAN-PRODUKTIV.md](FAHRPLAN-PRODUKTIV.md)

Fehlende Module sollen **404** liefern; der Client blendet die UI dann aus.
