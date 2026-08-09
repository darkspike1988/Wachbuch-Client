# Pilot Wachalltag (Welle 2 Phase 6)

Prozess-Rahmen für eine Partnerwache — **kein** Code-Deliverable.

## Ziel

2–4 Wochen produktive Nutzung von Schichtübergabe + Mängel + Gerätestatus
auf einer selbst gehosteten Wache, ohne ELS/Alarmierung.

## Auswahl Partnerwache

- Eine Organisation (RD **oder** BF **oder** FFW **oder** Polizei)
- Schichtleitung als Ansprechperson
- Staging oder isolierte Prod-Instanz mit Backup

## Ablauf

1. **Kickoff** — Contract + Produktgrenze erklären; Accounts anlegen  
2. **Enablement** — Module `defects`/`assets` (optional `inventory`) aktivieren  
3. **Schulung** — E2E-Checkliste `E2E-WACHALLTAG.md` einmal gemeinsam durchspielen  
4. **Betrieb** — tägliche Nutzung; Feedback-Kanal (Issue/Mail)  
5. **Review** — was fehlt für Breiten-Rollout; keine Feature-Creep in ELS

## Betriebliche Mindestpunkte

- Server-Backup/Restore dokumentiert (Server-Repo)
- Client-Update-Pfad (Store / interner Build) geklärt
- Keine sensiblen Einsatzdaten in Demo-Fixtures auf der Pilot-Instanz
- Optional später: stille Push nur als Zähler (kein Lockscreen-Inhalt)

## Exit-Kriterien Pilot

- Mindestens eine volle Schichtwoche mit Mängeln + Quittierung genutzt
- Keine Blocker-Bugs ohne Workaround
- Entscheidung: Play/TestFlight-Externals ja/nein
