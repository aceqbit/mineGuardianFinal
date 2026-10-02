# Architecture

```
Flutter app (mobile/)                         Node API (backend/)                       Services
─────────────────────                         ───────────────────                       ────────
go_router + role guard                        Express, module auto-loader               MongoDB Atlas
BLoC per feature (+ RxDart streams)           modules/<name>/index.js                   Firebase Auth / Storage / FCM
dio ApiClient (Bearer ID token)               core/{bus,socket,auth,storage,...}        Gemini Flash (+ YOLO via Roboflow or ONNX)
SocketService (envelope + dedupe)  <──ws──>   Socket.io rooms user/role/zone/public     Twilio (dry run by default)
SQLite outbox + SyncEngine (offline-first)    node-cron (scoring, rewards, SLA, reports)
GlobalOverlays (crisis, siren, broadcasts)
```

## Rules the design follows

1. **Contract first.** REST routes, socket events, bus events and enums are frozen strings shared by `backend/src/contracts` and `mobile/lib/contracts` (`dev/contract-check.js` compares them). Payload shapes added later are in `docs/PHASE2_PAYLOADS.md`.
2. **The server decides, the AI suggests.** The analyser fills a schema-locked result; deterministic guardrails and YOLO fusion run afterwards; a supervisor makes the decision. Any AI failure becomes `NEEDS_MANUAL_REVIEW`, never a guess.
3. **Offline first.** Check-ins, hazards, SOS and GPS go through one SQLite outbox with priorities (SOS 0, cancel 1, hazard 2, check-in 3, GPS 4) and idempotent client ids, so a retry never creates a duplicate. The evacuation map and first-aid guides are cached.
4. **Blast first, persist after.** Crisis activation and broadcasts emit to sockets before any database write; Twilio and FCM run in `Promise.allSettled` and never block.
5. **Memory is authoritative during a crisis.** Positions, timeline and pings are buffered and flushed behind the scenes (pings 15 s, timeline 5 s); an ACTIVE crisis is restored from Mongo after a restart.
6. **Modules never edit `app.js`.** The loader mounts every `modules/*/index.js` that exports `{ name, basePath }` and awaits its `init()`. Phase 1 modules read Phase 2 collections only through raw reads, so Phase 1 runs without Phase 2.

## Module map (backend)

| Module | Base path | Owns |
|---|---|---|
| auth, users, zones | `/api/auth`, `/api/users`, `/api/zones`, `/api/layout` | accounts, roles, zone polygons, mine layout (ETag by version) |
| checkins, hazards, sos | `/api/checkins`, `/api/hazards`, `/api/sos` | uploads, integrity flags, status rules, SOS SMS |
| feed, admin-overview | `/api/feed`, `/api/admin` | supervisor snapshot, admin overview |
| ai-analyzer | `/api/ai` | analysis queue, agent, fusion, evaluation |
| compliance | `/api/compliance` | review decision rules, PDF |
| scoring | `/api` (`/leaderboard`, `/scores`) | score snapshots, leaderboard, risk bands |
| rewards | `/api/rewards` | monthly honours |
| admin-normal | `/api/admin` | SLA watchdog, reliability, hazard audit, reports |
| crisis (+ rerouter) | `/api/crisis` | crisis engine, routing |
| public-track | `/public` | tokenised status page |
| broadcast, contacts | `/api/broadcasts`, `/api/contacts` | messaging and emergency contacts |

## Data

`users`, `zones`, `layouts`, `check_ins`, `compliance_reviews`, `hazards`, `sos_events`, `audit_logs`, `score_snapshots`, `rewards`, `reports`, `crises`, `crisis_reports`, `gps_pings`, `broadcasts`, `broadcast_replies`, `emergency_contacts`.

## Time

All day, shift and score logic runs in Asia/Kolkata (UTC+5:30). Cron: scoring `10 0 * * *`, rewards `30 0 1 * *`, daily report `55 23 * * *`, SLA watchdog every minute (every 10 s with `DEMO_FAST_MODE`).
