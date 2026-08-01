# Wachbuch-Client

Monorepo für den **Wachbuch-Client** und die Review-Remediation des
Servers [Rettungswache-Wachbuch](https://github.com/darkspike1988/Rettungswache-Wachbuch).

| Pfad | Inhalt |
|---|---|
| `backend/` | Django-Server inkl. Review-Fixes (AGPL-3.0) |
| `client/` | Installierbare PWA-Hülle gegen `/api/v1/` |
| `PLAN.md` | Umsetzungsplan aus der Code-Review |

## Warum dieses Repo?

Der Cloud-Agent hat aktuell **keinen Schreibzugriff** auf
`darkspike1988/Rettungswache-Wachbuch` (`cursor[bot]` → 403). Die Server-Änderungen
liegen deshalb hier unter `backend/` und sollen nach Freigabe der Cursor-GitHub-App
zurück ins Upstream-Repo synchronisiert werden.

## Backend starten

```bash
cd backend
cp .env.example .env
# Zufallswerte setzen, siehe backend/README.md
sudo chown 70:70 backups
docker compose up --build -d
```

## Client

Statische PWA unter `client/`. Nach Login im Server (Session-Cookie) die API-Basis-URL
setzen und „Aktualisieren“ wählen. Endpunkte:

- `GET /api/v1/me/`
- `GET /api/v1/dashboard/`
- `GET /api/v1/handovers/`

## Tests

```bash
cd backend
pip install -r requirements.txt
DJANGO_SECRET_KEY=ci-only-secret DJANGO_DEBUG=false \
  python manage.py test --settings=config.test_settings
```
