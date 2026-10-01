# Requirements traceability (35 client requirements)

Every requirement maps to a build step and a demo moment. The last column points to the row of `docs/E2E_SCRIPT.md` that shows it.

| ID | Requirement | Built in | Where to see it |
|---|---|---|---|
| 1A-i | No default +91, no pre-filled fields, no timer resets, no random cached values | S0.3 rules, P1.2 | E2E 1 |
| 1A-ii | Separate animated country-code dropdown and number field with precise validation | P1.2, P1.3 | E2E 1, sign-up |
| 1A-iii | 6-character password replaces the 4-digit PIN | P1.1, P1.2, P1.3 | E2E 1, sign-up |
| 1A-iv | Sign-up page with detailed fields saved in MongoDB | P1.1, P1.3 | sign-up, `users` collection |
| 1A-v | Remove "Secure login"; Miner and Supervisor login route to the right role | P1.2 | E2E 1 |
| 1A-vi | Admin login plus a sample admin account and admin page | S0.2 (seed), P1.2, P1.11 | E2E 1 |
| 1B-1 | White and dark colour system | S0.4 | `/dev/ui` light and dark |
| 1B-2 | Polished styling and smooth animations | S0.4 and every UI step | every screen |
| 1B-3 | Aligned boxes, layouts adapt on web and mobile | S0.4 responsive system | every screen at 360, 768, 1280 px |
| 1B-4 | Centred tile icons, images instead of empty boxes | S0.4 (MediaTile), P1.4, P1.11 | Worker Home, Admin Home |
| 2-1 | Worker has no tick boxes, only capture or insert image | P1.5, P1.8 | E2E 2, 3, 6 |
| 2-2 | Photo gate detects cut-off, blurred and dark photos and forces a retake | P1.5, P1.6 | E2E 2 |
| 2-3 | Photo timestamps kept and monitored | P1.5, P1.6, P2.4 | E2E 4, 5 |
| 2-4 | Big animated status ticker | P1.6 | E2E 3 |
| 2-5 | PPE checklist moves entirely to the supervisor | P2.4 | E2E 5 |
| 3-1 | ML and CV predict compliance the moment the photo arrives | P2.1, P2.2, P2.3 | E2E 3, 4 |
| 3-2 | Detailed report to the supervisor | P2.3, P2.4 | E2E 4, 5 |
| 3-3 | Supervisor decides every checklist option after seeing the ML output | P2.4 | E2E 5 |
| 3-4 | Predicted emergency goes to admin and turns crisis mode on; crisis mode is not always on | P2.3, P2.8 | E2E 8 |
| 3-5 | Live dashboard with a complex score | P2.5 | E2E 5 |
| 3-5b | Live dashboard visible to everyone | P2.5 | `/leaderboard` as any role |
| 3-6 | Monthly rewards: badges, stars, honours, incentives, extra holidays | P2.6 | E2E 15 |
| 4-i-1 | Admin reviews supervisors who miss the SLA | P2.7 | E2E 7 |
| 4-i-2 | Data in the DB; reports generated, stored, shareable | P2.7 | E2E 7, 14 |
| 4-ii-1 | Admin takes over during crisis or SOS | P2.8, P2.10 | E2E 8 |
| 4-ii-2 | GPS-based evacuation rerouter | P2.9 | E2E 9, 10 |
| 4-ii-3 | GeoJSON map for the admin | P2.9, P2.10 | E2E 9 |
| 4-ii-4 | Shortest path plus constraints plus real-time heuristics, several routes | P2.9 | E2E 9, 10 |
| 4-ii-5 | Fast announcement interface and messages over WebSockets | P2.11 | E2E 11 |
| 4-ii-6 | APIs to contact police, fire, rescue, ambulance and the mining authority | P2.12 | E2E 12 |
| 5-1 | Works as a live demo on a phone | I.3 | the whole script on real phones |
| ML-1 | Gemini specialised with guardrails, tools, image analysis, criticality, summary | P2.1, P2.2 | E2E 3, 4; eval report |
| ML-2 | YOLO and classical ML as tools to the LLM | P2.2 | E2E 4 (tool trace); eval report |
| SUP | Zone supervisor flow customised end to end | P1.10, P2.4, P2.6, P2.7, P2.10 | E2E 4, 5, 7, 8, 13 |
| SPLIT | Two phases with minimal coupling through the shared contract | contract, P1.12, P2.13 | `p1-smoke`, `p2-smoke`, I.1 |

Also carried over: offline SQLite queue and sync counter (P1.7), Twilio SMS on hazard (P1.8), Gemini hazard severity (P2.3),
30-minute SLA with three exponential reminders, streak freeze and compensation (P2.7), nightly risk profiling (P2.5), live GPS and
a public share link (P2.8), audit log (core), acoustic siren and SYSTEM SAFE sign-off (P2.10).

Dropped on purpose: the miner tick-box daily checklist (moved to the supervisor), the 4-digit PIN, voice-to-text in hazard reports.
