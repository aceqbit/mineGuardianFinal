# Mine Guardian

Offline-first safety app for underground mines. Workers check in with a photo; an AI model suggests a PPE verdict; supervisors decide. Hazard reports, SOS with an offline evacuation map, live scoring, and a crisis mode with ranked evacuation routes, broadcasts and emergency contacts.

* `backend/` Node 20, Express, MongoDB, Socket.io, Firebase Admin. Modules load automatically from `src/modules/`.
* `mobile/` Flutter (Android, iOS, Web). BLoC, go_router, SQLite outbox.
* `docs/` build contract (`CLAUDE.md` at the repo root is the source of truth), progress, audits, runbook.

## Run it

See `docs/DEMO_RUNBOOK.md`. Short version:

```bash
cd backend && npm install && npm run seed && npm run dev
cd mobile && flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

## Check it

```bash
cd backend && npm test                      # unit tests, no network needed
node dev/contract-check.js                  # backend and Flutter contracts match
cd mobile && flutter analyze && flutter test
dart run tool/route_check.dart
```

Checks that need live accounts (`dev/p1-smoke.js`, `dev/phase2/p2-smoke.js`, AI evaluation, real phones, Twilio) are listed in `docs/FINAL_AUDIT.md` as manual.

## Safety defaults

* Twilio runs in dry run unless `TWILIO_DRY_RUN=false`; the server refuses to dial real emergency numbers.
* The AI never decides: failures become "needs manual review", and a supervisor confirms every result.
* Secrets stay out of git (`.env`, `secrets/`, `*.local.json`).
