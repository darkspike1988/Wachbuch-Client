# Release-Versionierung (Wachbuch Client)

Dieses Dokument beschreibt, wie App-Versionen geführt werden, was ein
Release-Commit ist und welche Voraussetzungen für einen echten Store-Upload
noch fehlen. Es ist die Kurzreferenz zum maschinenlesbaren Vertrag in
[`release/release-contract.json`](../release/release-contract.json) und zur CLI
[`scripts/release_version.py`](../scripts/release_version.py).

## Quelle der Wahrheit

`pubspec.yaml` ist die einzige Quelle der App-Version im Format
`MAJOR.MINOR.PATCH+BUILD`, z. B. `1.0.0+12`.

* Android (`android/app/build.gradle*`): `versionCode = flutter.versionCode`,
  `versionName = flutter.versionName`.
* iOS (`ios/Runner/Info.plist`): `CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)`,
  `CFBundleVersion = $(FLUTTER_BUILD_NUMBER)`.

Beide Plattformen lesen damit denselben Wert; es gibt keine getrennten
Buildnummern.

## Regeln

1. **App-Version SemVer-Kern** `MAJOR.MINOR.PATCH`, keine führenden Nullen,
   keine Pre-Release-Suffixe für Store-Builds.
2. **Buildnummer** ist eine positive ganze Zahl (`^[1-9][0-9]*$`), ohne führende
   Nullen.
3. **Eine gemeinsame Buildnummer über alle App-Versionen**: Die Buildnummer wird
   nie zurückgesetzt. Sie steigt mit jedem Build, auch über App-Versionssprünge
   hinweg (`1.0.0+12` → `1.0.0+13` → `1.1.0+14`, nie `1.1.0+1`).
4. **Tags** enthalten das Build, sobald Tagging eingeführt wird:
   `v{MAJOR.MINOR.PATCH}+{BUILD}` (z. B. `v1.0.0+13`).
5. **CI-Run-Versuche sind keine Buildidentität.** `github.run_number`,
   `run_attempt` o. Ä. dürfen nie als Store-Buildnummer verwendet werden.
6. **Buildidentität**: Eine einmal veröffentlichte Kombination
   `Appversion+Buildnummer` darf **nie** aus einem anderen Quellstand erneut
   veröffentlicht werden. Normale CI-Reruns und unveränderte `pubspec.yaml` auf
   anderen Entwicklungscommits sind dagegen erlaubt. Durchgesetzt wird das über
   das Build-Identitäts-Ledger
   [`release/release-ledger.json`](../release/release-ledger.json) und
   `release_version.py publish-guard`. Bislang ist das ein lokaler Prüfbaustein,
   keine dauerhaft fortgeschriebene Store-Historie.

Ein **Release-Commit** ist ein Commit, der die Version in `pubspec.yaml`
gegenüber dem Eltern-Commit ändert. Nur solche Commits – und nur bei aktivierter
Beta-Automatisierung – können signierten Pipelines auslösen.

## CLI

```bash
python3 scripts/release_version.py show --json
python3 scripts/release_version.py validate --require-main --ref "$GITHUB_REF" --json
python3 scripts/release_version.py next-build --prev 12
python3 scripts/release_version.py publish-guard \
  --ledger release/release-ledger.json --version 1.0.0+13 --sha "$(git rev-parse HEAD)" --json
python3 scripts/release_version.py check --kind contract --input release/release-contract.json
```

* `validate` ist **fail closed**: jeder Verstoß liefert Exit-Code 1 und eine
  maschinenlesbare Fehlerliste (`code`, `message`).
* `validate` prüft **nur die Format-/Konsistenzregeln**. Es erzwingt **keinen**
  Versionsbump pro Pull Request – ein CI-Syntaxguard darf normale PRs nicht
  blockieren. Die Build-Monotonie greift nur mit `--prev-build`/`--prev-name`.
* Tests: `python3 -m unittest discover -s scripts/tests -p 'test_*.py'`.

## Plattformgrenzen (Stand: extern verifiziert)

* **Apple**: `CFBundleVersion` ist laut offizieller Doku eine Zeichenkette aus
  ein bis drei punktgetrennten Ganzzahlen (Ziffern `0-9` und Punkte); ein
  einzelner Integer wie `10` ist zulässig. Eine Obergrenze für die Länge/
  Ziffernzahl wird dort **nicht** genannt. Die oft zitierte 4-Ziffernregel wird
  hier bewusst **nicht** als harte Grenze erzwungen.
  Quelle: <https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion>
* **Android**: `versionCode` ist eine positive Ganzzahl, die bei jeder
  Veröffentlichung steigen muss.
  Quelle: <https://developer.android.com/studio/publish/versioning>

Für die gemeinsame Buildnummer erzwingt die CLI die dokumentierte Google-Play-
Obergrenze **2100000000**. `--max-build` kann diese weiter einschränken, nicht
erweitern. Überlange Zahlen werden vor der Integer-Konvertierung abgewiesen.

## Beta-Orchestrierung

[`.github/workflows/beta-release.yml`](../.github/workflows/beta-release.yml)
koppelt die bestehenden signierten Pipelines konservativ:

* nur `main`, feste Commit-SHA, globale `concurrency`;
* Opt-in über Repository-Variable `WACHBUCH_BETA_RELEASE` (**Default: aus**);
* bestehende CI als harte Voraussetzung vor jedem signierten Build;
* `publish-guard` als lokaler Konsistenzcheck;
* **Publisher hart deaktiviert**: Auch Opt-in plus `publish=true` scheitert
  ausdrücklich. Dauerhaftes Release-Ledger und Store-Verarbeitungsnachweis
  fehlen. Dry-runs erstellen `plan.json` mit Version, Quell-SHA und Blockern;
* kein `workflow_run` (PR-Code läuft nie privilegiert);
* die signierten Workflows deklarieren `testflight` / `google-play`.
  Tatsächliche Reviewer-Schutzregeln sind **nicht bestätigt**. Secrets sind
  explizit deklariert, kein `secrets:inherit`.

## Wiederverwendbare Einstiegspunkte (vorbereitet, ungenutzt)

`ci.yml`, `testflight.yml` und `android-release.yml` besitzen einen additiven
`workflow_call`-Eintrag. **Aktuell ruft sie niemand auf**: Die
Beta-Vorbereitung enthält keine Publishing-Jobs. Die Einstiegspunkte sind
Grundlage für die spätere Orchestrierung, sobald dauerhaftes Ledger und
Store-Verarbeitungsnachweis existieren. Die deklarierten Secrets sind
`required: true`, ein Aufruf ohne vollständige Secrets scheitert also sofort.

## Server-Kopplung (Abgrenzung)

Der API-Vertrag liegt im Server-Repository unter `core/api/openapi_v1.yaml`
(`info.version: 1.4.0`). Die **Server-App-Version `0.16.x` allein ist kein
Kompatibilitätsnachweis**: Die revisionsgebundene Quittierung (S2) setzt den
API-Vertrag `1.4.0` voraus. Die Server-Versionsnummer ist kein
SemVer-Breaking-Change-Bump und nicht mit der Vertragsversion gleichzusetzen.

## Offene Voraussetzungen vor einem echten Upload

Dokumentiert, **nicht** Teil dieses Repository-Stands:

* GitHub-Repo-Secrets `[]` – alle Secrets der signierten Workflows fehlen
  (Apple-/Android-Uploadmaterial).
* Environments `testflight` und `google-play` liefern beim Abruf 404 – es gibt
  keinen bestätigten Nachweis für Environment-Schutzregeln (Required Reviewers).
* iOS: Testerzuordnung und Verarbeitungs-Poll noch nicht implementiert
  (nur Upload im Workflow vorhanden).
* Android: Workflow erzeugt nur signierte Artefakte, **kein** Play-Upload.
* Featurepaket-Version noch nicht erhöht (App und Server stehen auf dem
  Quellstand); es existiert **kein** bereits veröffentlichtes `1.1.0`.
