# Programmierfahrplan: Form follows function

## Ziel und Grenzen

Arbeitsauftrag: Architektur und Gestaltung folgen dem Wachalltag, nicht dekorativen
Dashboards. Jede Anzeige muss fachlich belegbar sein: aktueller Stand, Ladezustand,
Fehler, erlaubte Aktion und Ergebnis. Umsetzung in kleinen, einzeln geprüften Paketen.

- Entwicklungsbranch: `develop/wachbuch-modernisierung`, PR #66.
- Öffentliche Server-Demo bleibt unverändert. Kein Produktions-/Store-Rollout.
- Keine Patienten-/Einsatzdaten, keine neuen Fachfunktionen ohne Datenvertrag.
- Kein Microservice-Umbau und keine neue State-Management-Abhängigkeit.
- Offline bleibt ein Lesecache; keine implizite Schreibwarteschlange.
- App-/Server-/Vertragsversion sind unabhängig; API 1.4.0 ist für S2 erforderlich.

## FF-1 — Navigation und Fachansichten trennen

**Priorität P0. Lokal umgesetzt und getestet; native CI folgt dem Push.**

`HomeShell` übernimmt Navigation, Anmeldung und die bestehende gemeinsame
Übersichtsaktualisierung. Die Darstellung wurde in eigenständige Bibliotheken geteilt:

- `screens/overview_tab.dart`: Übersicht, Module und Geräteübersicht.
- `screens/handovers_tab.dart`: Filter, Übergabeliste und Öffnen eines Details.
- `screens/account_tab.dart`: Konto und Sitzungsaktionen.
- `screens/handover_detail_sheet.dart`: genau eine Übergabe und ihre Aktionen.
- `ui/handover_presentation.dart`: gemeinsame Status-/Prioritätsdarstellung.

Ergebnis: `home_shell.dart` von **1707 auf 266 Zeilen** reduziert, ohne
`part`-Dateien, Importzirkel oder Kopien der zentralen Darstellungsregeln.
Das ist kein pauschaler Abschluss aller Architekturarbeit: Mangelanlage bleibt
widgetgebunden; Übersichtsaktualisierung bleibt zunächst in HomeShell.

Abnahme: bestehende Navigations-/Modul-/Demo-Widgettests müssen unverändert bestehen;
Analyzer ohne Befunde. Neue öffentliche Widgets nehmen einen `key` entgegen.

## FF-2 — Quittierungszustand von Darstellung trennen

**Priorität P0. Lokal umgesetzt und getestet.**

`state/handover_ack_state.dart` ist eine ChangeNotifier-Zustandskomponente:

- nur API-Aufrufe und fachlicher Zustand, keine Widgets oder Übersetzungen;
- schreibgeschützte Zustandszugänge und unveränderliche Quittierungsliste;
- getrennte Lade- und Schreibfehler;
- verspätete GETs löschen keine erfolgreiche lokale POST-Quittierung;
- überholte Ladeantworten überschreiben keinen neueren Ladezustand;
- Doppelklick während POST erzeugt keinen zweiten Request;
- 409 bleibt ein Konflikt, kein automatischer Retry;
- Netzwerkfehler ist nicht gleich fehlende Serverfähigkeit;
- Antworten nach Dispose sind wirkungslos;
- fremde Objekt-IDs oder unpassende POST-Revisionen werden nicht als Erfolg angezeigt.

### Funktion bestimmt Anzeige

- Unbekannte gelesene Detailrevision sperrt das Quittieren.
- Eine Listen-/Fallbackrevision darf **nicht** die fehlende Detailrevision ersetzen.
- Laden wird explizit angezeigt, nicht als „Noch nicht quittiert“ ausgegeben.
- Ein Ladefehler erhält einen Wiederholen-Button; leere Historie wird erst nach
  erfolgreichem Laden behauptet.
- Bestehende Quittierungen bleiben sichtbar und sind revisionsgebunden.
- Lade-/Fehlermeldungen sind auf Deutsch und Englisch lokalisiert.

Abnahme: 13 isolierte Zustandstests plus 4 zusätzliche Widgettests, darunter
320px Breite mit doppelter Textskalierung. Listenrevision-Regressionsfall scheitert
auf dem alten Commit `4d46969` und besteht auf dem neuen Code.
Screenreader-/Gerätefreigabe wird daraus **nicht** abgeleitet.

## FF-3 — Reproduzierbare Kompatibilitäts- und Lieferprüfung

**Priorität P0. Lokale Gates bestanden; CI-Status separat nachweisen.**

1. Format, Analyzer und vollständige Flutter-Suite.
2. Bestehende 39 Release-Guard-Tests und Workflowprüfung.
3. Echter Flutter-API-Client **und neuer Quittierungszustand** gegen einen
   temporären Django-HTTP-Server:
   - erste Quittierung 201, Wiederholung 200;
   - Inhaltsänderung und veraltete Revision 409;
   - neue Revision quittierbar, alte Historie erhalten;
   - fehlende Pflichtrevision 422.
4. Native Android-/iOS-CI und Sicherheitschecks für den exakten Push-SHA.

Der wiederverwendbare Runner liegt unter `tool/qa/run_live_server.py`. Er verwendet
explizit `config.test_settings`, eine neue temporäre SQLite-Datenbank, einen
Loopback-Port und einen flüchtigen Testtoken. Er greift weder auf Demo-Daten noch
auf eine bestehende Datenbank zu. Logs enthalten nur Methode/Pfad/Status.

SQLite beweist hier den HTTP-Vertrag, **nicht** PostgreSQL-Rowlocking oder
Produktionslast. Ein unsignierter iOS-CI-Build ist keine Storeabnahme.

### Lokale Befehle

Im Client-Repository mit installiertem Flutter und aufgelösten Abhängigkeiten:

```bash
flutter analyze --no-pub
flutter test --no-pub
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

Die HTTP-Probe braucht die Python-Umgebung des Servers. Beispiel auf dem
Entwicklungssystem (Daten werden nur temporär erzeugt):

```bash
/opt/data/services/rettungswache-wachbuch/.venv/bin/python tool/qa/run_live_server.py \
  --server-repo /opt/data/workspace/wachbuch-modernisierung \
  --flutter /opt/data/toolchains/flutter/bin/flutter \
  --report-dir /opt/data/workspace/wachbuch-modernisierung-berichte/form-follows-function-20261009
```

## FF-4 — Weitere Fachbereiche und echte Nutzung

**Priorität P1. Geplant, nicht als erledigt markieren.**

- Mangelanlage aus Detail-Widget in typisierten Zustand/Service lösen.
- Übersichtsladen mit eindeutigem Lade-/Fehler-/Offlinezustand versehen.
- Übergabe-/Mangel-Detailantworten schrittweise als typisierte DTOs statt freier Maps.
- Gleiche Zustandskonvention bei Checklisten, Geräten und Inventar anwenden.
- Aufgabenreihenfolge gemeinsam mit Wachennutzern prüfen: Übersicht → offene
  Übergaben → konkrete Handlung; keine unbelegten Kennzahlen hinzufügen.
- VoiceOver/TalkBack, Handschuh-/Touchbedienung, Tablet, Rotation, Offline- und
  Sitzungswechsel sowie Upgrade aus tatsächlich installierter Vorversion testen.

Abnahme: negative Tests vor jeder Verhaltensänderung, echte Geräteprotokolle,
keine erfundene A11y-/Bedienfreigabe. Gerätezugang ist aktuell nicht belegt.

## FF-5 — Kontrollierter produktiver Rollout

**Priorität P0 vor Verteilung; extern blockiert.**

- S2/API-1.4.0-Server auf getrenntem Produktionsziel bereitstellen; öffentliche
  Demo weiterhin schützen. Backup/Restore und passende Rechte vorher prüfen.
- Kandidatenversion/Build bewusst erhöhen und an den geprüften Commit binden.
- Dauerhaften Release-/Buildidentitätsnachweis implementieren.
- Geschützte Store-Environments und Signier-/Uploadzugänge einrichten.
- TestFlight-Verarbeitung/Testerzugang und Play-internen Test tatsächlich prüfen.
- Erst dann Publishing-Jobs in der Beta-Orchestrierung hinzufügen.

Der bestehende Vorbereitungsworkflow darf derzeit keine automatischen Store-
Uploads auslösen, auch nicht bei gesetztem Opt-in. Ein grüner Build ersetzt
keinen Serverrollout, Gerätetest oder Store-Verarbeitungsnachweis.
