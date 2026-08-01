# Test- und Go-live-Checkliste

Ein erfolgreicher Docker-Start ist keine fachliche, datenschutzrechtliche oder
betriebliche Freigabe.

## Technik

- [ ] CI und Anwendungstests sind gruen
- [ ] Container-Healthchecks sind gruen
- [ ] Anwendung ist nur ueber den vorgesehenen TLS-Einstieg erreichbar
- [ ] Identitaetsheader koennen nicht von Clients gefaelscht werden
- [ ] `TRUSTED_PROXY_CIDRS` enthaelt ausschliesslich den Reverse-Proxy/Tailscale-Einstieg
- [ ] `/healthz/` ist von oeffentlichen Netzen nicht erreichbar
- [ ] Rollenmatrix wurde mit mehreren Testkonten geprueft
- [ ] Passwort-Login nutzt TOTP fuer privilegierte Konten (oder Tailscale-only)
- [ ] Retention-Lauf (`purge_expired_data`) ist geplant und getestet
- [ ] Backup wurde in einer isolierten Datenbank wiederhergestellt
- [ ] Abhaengigkeiten und Container-Images wurden gescannt (Trivy HIGH/CRITICAL)
- [ ] Monitoring, Alarmierung, Patch- und Incident-Prozess sind aktiv
- [ ] Cursor-GitHub-App hat Schreibzugriff auf Server- und Client-Repo (falls Agents deployen)

## Fachlichkeit

- [ ] Zweck, erlaubte Datenfelder und verantwortliche Stelle sind beschlossen
- [ ] Patienten-, Einsatz- und Gesundheitsdaten sind organisatorisch untersagt
- [ ] Rollen, Kalenderzweck und optionale Kassenregeln sind abgenommen
- [ ] Hinweise zu externen Quellen sind fachlich geprueft
- [ ] Aufbewahrungs- und Loeschfristen sind je Datenart festgelegt

## Datenschutz und Mitbestimmung

- [ ] anwendbares Datenschutz- und Mitbestimmungsrecht ist bestimmt
- [ ] Datenschutz, Informationssicherheit und Interessenvertretung sind beteiligt
- [ ] VVT, DSFA-Vorpruefung und Betroffeneninformation sind freigegeben
- [ ] Auskunft, Berichtigung, Loeschung und Incident-Meldung sind geregelt
- [ ] Audit-Zweck und Auswertungsverbot sind dokumentiert

## Produktion

- [ ] externer Sicherheitstest oder angemessene ASVS-Pruefung ist abgeschlossen
- [ ] Betreiberangaben, Datenschutzinformation und Supportweg sind vorhanden
- [ ] verschluesseltes Offsite-Backup und erfolgreicher Restore-Test existieren
- [ ] formale Go-live-Freigabe ist dokumentiert
