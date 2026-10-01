# Phase 1 audit

| Row | Requirement | Implementing files | One-line demo |
|---|---|---|---|
| 1A-i | Empty fields, no default +91, no timers | `mobile/lib/features/auth/view/login_screen.dart`, `widgets/country_code_picker.dart`; `test/login_screen_test.dart` | Open `/login`: country shows "Code", every field empty |
| 1A-ii | Animated country picker + precise phone validation | `features/auth/data/{countries,phone_validator}.dart`, `widgets/{country_code_picker,phone_field}.dart` | Pick a country; type `09876…` to see the leading-0 message |
| 1A-iii | 6-character password | `features/auth/data/password_rules.dart`, `widgets/password_field.dart` | Four live rule chips turn green |
| 1A-iv | Detailed sign-up saved in MongoDB | `backend/src/modules/auth/*`, `features/auth/view/signup_screen.dart` | Create a miner; check `users` |
| 1A-v | Role logins route correctly; mismatch fixable in one tap | `features/auth/bloc/login_bloc.dart`, `app/router.dart` | Miner credentials under Supervisor Login show the switch banner |
| 1A-vi | Admin login + sample admin + admin page | `backend/seed/seed.js`, `features/admin_home/*` | 9876500001 / Admin1 |
| 1B-1 | White and dark colour system | `app/theme/{tokens,app_theme}.dart` | `/dev/ui` in light and dark |
| 1B-2 | Smooth animations, reduced-motion aware | `app/theme/motion.dart`, `app/ui/*` | Every screen |
| 1B-3 | Aligned, responsive layouts | `app/responsive.dart`, `app/ui/app_scaffold.dart`; 3-width widget tests | Resize to 360, 768, 1280 px |
| 1B-4 | Centred tile icons, web images | `app/ui/media_tile.dart`, `app/app_images.dart` | Worker Home tiles |
| 2-1 | No tick boxes for the worker | `features/worker/view/{capture_screen,hazard_report_screen}.dart` | Only capture / insert photo |
| 2-2 | Gate blocks cut-off, blurred, dark photos | `features/worker/data/{quality_gate,image_metrics,pose_framing}.dart`, `backend/src/modules/checkins/image-quality.js` | Half-body photo gives "Feet not visible — step back" |
| 2-3 | Timestamps kept and flagged | `backend/src/modules/checkins/integrity.js`, `models/CheckIn.js` | Gallery photo from yesterday is flagged STALE |
| 2-4 | Animated status ticker | `features/worker/widgets/status_ticker.dart`, `bloc/checkin_flow_bloc.dart` | Submit a check-in |
| P1.7 | Offline outbox and sync indicator | `mobile/lib/core/{db,sync}/*`, `app/ui/sync_indicator.dart`; `test/sync_engine_test.dart` | Airplane mode, capture, restore |
| P1.8 | Hazard: photo + category + GPS, SMS to supervisors | `backend/src/modules/hazards/*`, `features/worker/view/hazard_report_screen.dart` | Report a hazard; see `[TWILIO DRY RUN]` |
| P1.9 | SOS and offline evacuation map | `backend/src/modules/sos/*`, `mobile/lib/features/sos/*` | Hold SOS 2 s; works in airplane mode |
| P1.10 | Supervisor live feed | `backend/src/modules/feed/*`, `features/supervisor_home/*` | Miner submits; card appears live |
| P1.11 | Admin home | `backend/src/modules/admin-overview/*`, `features/admin_home/*` | Reassign a supervisor |
| P1.12 | Simulators and smoke | `backend/dev/{simulate-phase2,p1-smoke}.js` | `node dev/p1-smoke.js` |

Manual checks still needed on real hardware: camera, ML Kit pose, blur calibration, airplane-mode sync, real SOS SMS share, push.
