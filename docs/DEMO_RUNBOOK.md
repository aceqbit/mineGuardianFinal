# Demo runbook

Do this once on the laptop, then rehearse `docs/E2E_SCRIPT.md` twice before showing it.

## 1. One-time setup (all MANUAL: these need your accounts)

1. `backend/.env`: copy `.env.example`, fill Mongo, Firebase project, storage bucket, `FIREBASE_WEB_API_KEY`, Gemini key. Keep `TWILIO_DRY_RUN=true`, `DEMO_FAST_MODE=true` for rehearsal.
2. Put the Firebase service account at `backend/secrets/firebase-sa.json`. Never commit it.
3. `cd mobile && flutterfire configure` (this overwrites the placeholder `lib/firebase_options.dart`).
4. Optional AI extras: Roboflow key and model path, or set `YOLO_PROVIDER=none`. Verify the current Gemini model id in `GEMINI_MODEL`.
5. Real photos: add `worker_full_body.jpg` and `hazard_cable.jpg` to `backend/seed/sample/` (see its README).
6. Optional real calls: copy `backend/seed/contacts.local.example.json` to `contacts.local.json` and put **team-verified** numbers in it. Never a real emergency number; the server refuses them.

## 2. Start

```bash
cd backend
npm install
npm run layout && npm run seed        # twice is safe
npm run seed:history                  # 45 days of check-ins, scores and last month's honours
npm run dev                           # expects "Mongo connected" and the module count
node dev/get-token.js 9876500101 Miner1
node dev/p1-smoke.js                  # all PASS
node dev/phase2/p2-smoke.js           # all PASS (leaves no active crisis)
node dev/contract-check.js            # all PASS

cd ../mobile
flutter pub get && flutter analyze && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

Phones need the laptop LAN address in `API_BASE_URL` (not localhost) and TCP 4000 open; otherwise use an HTTPS tunnel and set `PUBLIC_BASE_URL` to it.

## 3. Accounts

| Role | Phone | Password |
|---|---|---|
| Admin | 9876500001 | Admin1 |
| Supervisors | 9876500011 / 12 / 13 (Zones A / B / C) | Super1 |
| Miners | 9876500101 … 9876500112 | Miner1 |

## 4. Before every demo

* Backend running with `DEMO_FAST_MODE=true` (SLA steps in seconds, not minutes).
* No active crisis (admin console says "No active crisis"). `p2-smoke` leaves none.
* Airplane-mode toggle works on the miner phone; Chrome profiles are signed in for supervisor and admin.
* Browser audio: tap the "Enable siren" chip once so the siren can play.
* Twilio stays in dry run unless every number in `contacts.local.json` is verified.

## 5. If something breaks

| Symptom | Do this |
|---|---|
| Review card says "no review yet" | The AI is still working or failed: wait 30 s; a failed AI shows as manual review, decide it yourself |
| No routes for a worker | Admin console, "Recompute routes"; check no tunnel is blocked that cuts the worker off |
| Siren silent | Tap the chip; check the mute control |
| Phone cannot reach the API | LAN IP, firewall, or tunnel (see section 2) |
| Crisis will not resolve | Real crisis needs both checklist boxes and a note of 10+ characters; use "false alarm" for a drill |

The troubleshooting table in `CLAUDE.md` section 21 covers the rest.
