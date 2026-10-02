# Final audit

What was run on the build machine, what could not be, and what is still open. Nothing below is claimed beyond what was run.

## Ran and passed

| Check | Result |
|---|---|
| `cd backend && npm test` | 152 tests pass (one earlier full run showed 1 failure I could not reproduce in 20+ later runs or in repeated runs of the timing-sensitive files; not identified) |
| `cd mobile && flutter analyze` | 0 issues |
| `cd mobile && flutter test` | 120 tests pass, including 360 / 768 / 1280 px renders of every Phase 2 screen |
| `node backend/dev/contract-check.js` (offline part) | socket events and 23 enums identical in backend and Flutter; 56 route probes skipped because no server was running |
| `dart run mobile/tool/route_check.dart` | every contract route is registered; no placeholder screens remain |
| Syntax checks of `p2-smoke.js`, `demo_history.js`, `seed.js`, `contacts.js` | pass |

## Not run (manual, needs your accounts, hardware or photos)

1. `backend/.env`, Firebase service account, `FIREBASE_WEB_API_KEY`, `flutterfire configure` (the committed `firebase_options.dart` is a placeholder).
2. `node dev/p1-smoke.js`, `node dev/phase2/p2-smoke.js`, `node dev/contract-check.js` with the server running (live route probes).
3. Gemini and Roboflow keys; the current Gemini model id; a real AI run on a photo.
4. P2.0: 30 labelled evaluation photos and the 6 adversarial photos (`eval/adversarial.example.json` shows the format), then `node src/modules/ai-analyzer/eval/run.js` and `--set adversarial` (target 6/6 safe).
5. Blur calibration with real phone photos.
6. Real devices: camera and ML Kit pose, airplane-mode outbox, offline SOS, SMS share, push notifications, siren audio and vibration, web autoplay chip.
7. Twilio: verified team numbers only, after a dry run. `TWILIO_DRY_RUN` stays `true` until then.
8. `npm run seed` then `npm run seed:history` against a real database, and the 15-step script in `docs/E2E_SCRIPT.md`.
9. Dark-mode and visual polish review on screen.

## Known gaps and choices

* **Supervisor broadcast composer:** the API lets a supervisor broadcast to their own zone (tested), but only the admin has a composer screen. Supervisors receive banners and can reply.
* **Frozen contract:** three routes were added after the freeze (`docs/PHASE2_PAYLOADS.md`). No frozen name changed.
* **Payload shapes** for Phase 2 socket events were defined by this build (the spec froze names, not shapes); they are documented in `docs/PHASE2_PAYLOADS.md`.
* **Scoring details the spec left open:** badge set (7 and 30 day streak, perfect week, hazard hero, first-pass pro), XP (10 per compliant day, 15 per closed hazard, badge bonus), supervisor board metric (share of reviews decided inside the SLA). All in `modules/scoring/score.formula.js`.
* **Rewards:** top three each month get demo stars, an amount and holidays. Every amount is labelled "demo value" in the app.
* **Contacts:** demo dial targets default to the seeded admin phone; use `seed/contacts.local.json` for real team-verified numbers.
* **Hazard audit and SLA** use the review `sla` object written when the AI result arrives; reviews created before P2.3 have none and are ignored by the watchdog.
* **Commit authorship:** all commits use the machine's git identity with a `Co-Authored-By: Claude` trailer. Commits were not attributed to other people's GitHub accounts.
