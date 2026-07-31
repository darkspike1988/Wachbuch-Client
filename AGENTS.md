# AGENTS.md

## Cursor Cloud specific instructions

This repo is the **cross-platform mobile client** (iOS + Android) for the
`Rettungswache-Wachbuch` server. It is an **Expo (React Native + TypeScript)** app
(SDK 57). A single codebase targets iOS and Android; Expo web is used for quick
testing on this Linux VM.

### Dependencies / run

- Install: `npm install` (this is also the startup update script for this repo).
- Start: `npm run web` (browser), `npm run android` (emulator/device),
  `npm run ios` (macOS only). Typecheck: `npx tsc --noEmit`.
- There are no automated tests yet.

### Non-obvious caveats

- **iOS builds require macOS/Xcode** and are not possible on this Linux VM. Develop
  and test cross-platform behavior via Expo web here, and via Expo Go / EAS for the
  native platforms. Android builds are feasible on Linux with the Android SDK.
- **Backend URL** is read from `EXPO_PUBLIC_API_URL` (default `http://127.0.0.1:8090`,
  see `src/api.ts`). `EXPO_PUBLIC_*` vars are inlined at bundle time, so **restart
  the Expo dev server after changing them**. Android emulators must use
  `http://10.0.2.2:8090` (not `127.0.0.1`) to reach the host.
- **CORS only affects the web target.** Native iOS/Android have no CORS, so they can
  call the server directly. The server's `/healthz/` does not send CORS headers, so
  when testing via Expo **web** in a browser, run a dev CORS proxy in front of the
  server and point `EXPO_PUBLIC_API_URL` at it, e.g.:
  `npx local-cors-proxy --proxyUrl http://127.0.0.1:8090 --port 8010 --proxyPartial ""`
  then `EXPO_PUBLIC_API_URL=http://localhost:8010 npm run web`. This proxy is a
  dev-only helper and is not part of the app.
- The app consumes the server's versioned JSON API under `/api/v1/` (see the
  server's `docs/API.md`). It authenticates via `POST /api/v1/anmeldung/` and sends
  the returned bearer token on every request (`src/api.ts`); no cookies/CSRF.
- **Platform-adaptive design** lives in `src/design.tsx`: iOS gets current iOS
  elements incl. a translucent "liquid glass" tab bar (`expo-blur`), Android gets
  Material 3 (purple surfaces, elevation, a FAB for primary create). On native,
  `Platform.OS` picks the language automatically. On **web** it defaults to iOS and
  can be forced with `?design=ios|android` or the on-screen pill toggle
  (`DesignSwitcher`, web-only) — this toggle exists purely to preview both looks in
  the browser.
- **Kalender**: uses the open-source `react-native-calendars` (month grid, multi-dot
  marking) and shows three overlaid sources: server events (synced via the API +
  TanStack Query), German public holidays (`date-holidays`, region in
  `src/holidays.ts`, default NRW `DE/NW`), and a local waste schedule
  (`src/muell.ts`). The waste schedule is deterministic sample/config data meant to
  be replaced by a real municipal ICS feed later. A banner announces the next-day
  waste pickup; on native, `src/reminders.ts` also schedules an evening-before local
  notification via `expo-notifications` (best-effort, no-op on web / in Expo Go).
- Known RN-web quirk: list/scroll content on some screens can paint blank for a
  moment right after navigation/creation (it settles on interaction/resize); it is
  a web capture artifact, not present on native. Screenshots taken after the view
  settles show the real content.
