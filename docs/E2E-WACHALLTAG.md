# E2E-Checkliste Wachalltag (Welle 2 Phase 2)

Manuelle Abnahme gegen **Demo-Host** oder Staging.

## Voraussetzungen

- App-Build mit aktuellem Client
- Demo: Start → „Demo-Modus“ → Org wählen  
  oder Staging-URL + Token (kein `demo-*.wachbuch.local`)
- Module `defects` / `assets` in `/me/` aktiv (Demo: immer)

## Pfad Demo / Staging

| # | Schritt | Erwartung |
| --- | --- | --- |
| 1 | Login / Demo starten | Übersicht mit Station und Modulen |
| 2 | Schnellzugriff → Mängel | Liste lädt; FAB „Mangel“ sichtbar |
| 3 | Mangel anlegen (Titel Pflicht) | Neuer Eintrag oben; Snackbar Erfolg |
| 4 | Mangel öffnen → Status `waiting` | Chip/Liste aktualisiert |
| 5 | Detail → „Demo-Beleg hinzufügen“ | Anhang in Liste (Demo); Staging: 404 ok |
| 6 | Übersicht / Geräte → Asset tippen | Status setzen + Notiz speichern |
| 7 | Inventar Checkout/Checkin (wenn Modul) | Holder wechselt |
| 8 | Übergabe öffnen → „Übernommen“ | Quittierung erscheint |
| 9 | Übergabe → „Als Mangel“ | Mangel aus Titel/Details |
| 10 | Auswertung | Offene Mängel, Ampel-%, überfällige Checks |
| 11 | Offline (Flugmodus) nach einmaligem Online-Load | Offline-Stand-Hinweis; Listen lesbar |
| 12 | Logout | Cache geleert; kein alter Stand nach neuem Login anderer Org |

## Abnahme Staging

- Kein Demo-Banner
- 404 auf fehlenden Modulen ohne App-Crash
- Keine Patienten-/Vorgangsdaten in UI oder Logs
