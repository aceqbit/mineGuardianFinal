# 15-step end-to-end script

Devices: Phone A is the miner (Zone B, 9876500105), Phone B the Zone B supervisor (9876500012), the laptop is the admin on Flutter
Web (9876500001). Backend on the laptop with `DEMO_FAST_MODE=true` and `TWILIO_DRY_RUN=true` for the rehearsal. With no spare phones use an
Android emulator for the miner and two Chrome profiles for the supervisor and admin.

| # | Action | Expected on screen | Steps |
|---|---|---|---|
| 1 | Log in on all three with Miner, Supervisor and Admin Login | Each lands on its own home; nothing pre-filled | P1.2, S0.3 |
| 2 | Phone A: Capture Shift Photo with half the body cut off | Gate blocks: "Feet not visible — step back" | P1.5 |
| 3 | Phone A: a proper full-body photo | Ticker: Checking, Uploading, Synced, AI analysing, Done | P1.5, P1.6, P2.3 |
| 4 | Phone B | Card appears live ("AI analysing…"), then verdict, criticality and summary | P1.10, P2.3 |
| 5 | Phone B: open the Review Card, check the boxes on the photo, decide every item, override one with a note | Worker gets "Reviewed"; score and leaderboard update live | P2.4, P2.5 |
| 6 | Phone A: airplane mode, report a hazard (cable), airplane mode off | Queued, then syncs; Phone B gets the hazard card; severity arrives | P1.7, P1.8, P2.3 |
| 7 | Leave a second check-in undecided | Admin Normal Mode: reminders tick, then SLA breach toast; approve compensation | P2.7 |
| 8 | Phone A: hold SOS for 2 s | Panic screen; admin flashes red, siren and console; supervisor banner | P1.9, P2.8, P2.10 |
| 9 | Admin: view 3 ranked routes for the SOS worker, "Send to worker" | Phone A's map shows the green control-room route | P2.9, P2.10, P1.9 |
| 10 | Admin: block a tunnel on that route | Routes recompute on admin and Phone A within about 1 s | P2.9 |
| 11 | Admin: EMERGENCY broadcast to Zone B; Phone A replies | Banners in under 1 s; delivered and read counts; reply in the admin inbox | P2.11 |
| 12 | Admin: Contacts, call "Mines Rescue Station" (dry run), then Notify all | Status chips; timeline entries | P2.12 |
| 13 | Supervisor marks workers SAFE; admin resolves SYSTEM SAFE | Banners clear everywhere; post-crisis summary and PDF | P2.8, P2.10 |
| 14 | Admin: generate a report, copy the share link, open it on Phone B | PDF opens | P2.7 |
| 15 | Admin: publish rewards (demo), open Rewards on Phone A | Honours, stars, incentives and extra holidays shown | P2.6 |
