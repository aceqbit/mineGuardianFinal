# Phase 2 audit

Status words: **PASS** = checked by a test or command that ran. **MANUAL** = needs real accounts, hardware or photos; the code is in place.

| Row | Requirement | Implementing files | Evidence |
|---|---|---|---|
| P2.1 | Two-stage analyser, schema-locked output, deterministic guardrails | `backend/src/modules/ai-analyzer/{analyzer,agent,guardrails,schemas,prompts}.js` | PASS `ai.guardrails`, `ai.analyzer` tests. Real Gemini run: MANUAL |
| P2.2 | Tools, YOLO fusion rules a–h, evaluation harness | `ai-analyzer/{fusion.js,tools/*,eval/*}` | PASS `ai.fusion`, `ai.yolo.parse`. Eval on real photos: MANUAL (P2.0) |
| P2.3 | Analyser wired to the system; failures degrade to manual review | `ai-analyzer/{pipeline,jobs,index}.js` | PASS `ai.jobs`. Live pipeline: MANUAL |
| P2.4 | Review card, decision rules, PDF | `backend/src/modules/compliance/*`, `mobile/lib/features/compliance_review/*` | PASS `compliance.decision` (backend), `review_screen_test` (3 widths, lock on `compliance:reviewed`) |
| P2.5 | Score formula, streak, badges, ranking, risk bands (staff only) | `modules/scoring/*`, `models/ScoreSnapshot.js`, `features/leaderboard/*` | PASS `scoring.formula` (perfect worker 1000, frozen days, Sunday skipped, H clamp), `leaderboard_test` |
| P2.6 | Monthly honours, idempotent publish, demo labels | `modules/rewards/*`, `seed/demo_history.js`, `features/rewards/*` | PASS `rewards.test`, `rewards_test`. `npm run seed:history`: MANUAL |
| P2.7 | SLA watchdog (0/5/15/35 min), reliability, compensation, hazard audit, daily PDF | `modules/admin-normal/*`, `features/admin_normal/*` | PASS `sla.test` (schedule, no resend after restart, reliability), `admin_normal_test` |
| P2.8 | Crisis engine: blast first, merge, positions, accounted, resolve, report, public page | `modules/crisis/{crisis.engine,crisis.logic,crisis.report}.js`, `modules/public-track/*` | PASS `crisis.logic.test` (merge, resolve rules, tokens, page content). Live blast: MANUAL (`p2-smoke`) |
| P2.9 | Rerouter | `modules/crisis/rerouter/*` | PASS `rerouter.test`: A* equals Dijkstra on 50 pairs, blocked edge changes rank 1, CRITICAL hazard removes edges within 15 m, FIRE_SMOKE prefers intake, 13-worker recompute ≈ 10 ms |
| P2.10 | Crisis console, crisis view, overlays, siren | `features/crisis/*`, `app/{global_overlays,siren}.dart` | PASS `crisis_test` (bloc, 3 widths, miner evacuation redirect, siren WAV). Audio and vibration on a device: MANUAL |
| P2.11 | Broadcast | `modules/broadcast/*`, `features/broadcast/*`, `app/global_overlays.dart` | PASS `broadcast.test` (scope rules, SMS cap, acks), `broadcast_test` |
| P2.12 | Emergency contacts safety guard | `modules/contacts/*`, `features/contacts/*`, `seed/contacts.js` | PASS `contacts.test` (every blocklisted number refused), `contacts_test` (warning before dialling) |
| P2.13 | `p2-smoke` and adversarial set | `backend/dev/phase2/p2-smoke.js`, `ai-analyzer/eval/adversarial.example.json` | Script written and syntax-checked. Running it: MANUAL (needs the server, Firebase and Mongo) |

## Safety rules checked in code

* Twilio defaults to dry run; `makeCall` and `sendSms` never throw and never block a response or a socket emit.
* `dialE164` is validated on update and again before every call, SMS and notify-all. Notify-all refuses the whole batch if any stored target is unsafe.
* Miners never receive the crisis share token, the risk bands, or `dialE164`.
* The AI only suggests. A review is decided by a supervisor, and CONFIRM is refused whenever the AI said UNCERTAIN or any row differs.
* Crisis mode starts only from the five defined triggers, and resolving a real crisis needs both checklist items.
