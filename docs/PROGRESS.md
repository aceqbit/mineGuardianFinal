# Progress

| Step | Title | Status |
|---|---|---|
| S0.1 | Backend skeleton and core services | PASS (tests); boot needs .env |
| S0.2 | Models, layout, seed, /me | PASS (tests, layout); seed needs Firebase+Mongo |
| S0.3 | Flutter foundation | PASS (analyze 0, tests); flutterfire configure MANUAL |
| S0.4 | Design system and UI kit | PASS (analyze 0, tests, images 12/12); visual check MANUAL |
| P1.1 | Auth/users/zones API | PASS (tests) |
| P1.2 | Login screen | PASS (analyze, tests, 3-width render); real-phone login MANUAL |
| P1.3 | Sign-up flow | PASS (analyze, 3-width render test); end-to-end create MANUAL |
| P1.4 | Worker Home | PASS (analyze, 3-width test with neutral stats) |
| P1.5 | Capture + quality gate | PASS (analyze, gate/framing unit tests); camera, ML Kit and blur calibration MANUAL |
| P1.6 | Check-in upload API + StatusTicker | PASS (backend 26 tests, ticker 3-width test); phone upload MANUAL |
| P1.7 | Offline outbox + sync engine + indicator | PASS (8 engine tests, 53 total); airplane-mode test MANUAL |
| P1.8 | Report Safety Hazard | PASS (backend 31 tests, 3-width render); phone/offline report MANUAL |
| P1.9 | SOS + panic screen + offline evac map | PASS (backend 33, 6 evac-graph tests, 4 SOS screen tests incl. offline queue); real-phone SOS/SMS/offline MANUAL |
| P1.10 | Supervisor Home live feed | PASS (backend 34, 6 feed-bloc tests incl. live merge/optimistic rollback) |
| P1.11 | Admin Home | PASS (3-width render x crisis on/off); backend overview/supervisors added in P1.10 commit |
| P1.12 | Simulators + p1-smoke + audit | PASS (35 backend tests incl. simulator route builder); p1-smoke needs live server + Firebase = MANUAL |
| P2.0 | Prep (eval photos + labels) | MANUAL: 30 eval photos + labels.json are yours to make |
| P2.1 | AI analyser core | PASS (22 tests: guardrails, failure policy, mock, schemas); real-key checks MANUAL |
| P2.2 | Tools, tool loop, fusion, eval | PASS (72 backend tests: fusion rules a-h, YOLO parse/ONNX decode, metrics); eval run + real keys MANUAL |
| P2.3 | Wire the analyser into the system | PASS (76 tests incl. job queue); live pipeline run needs Mongo/Firebase = MANUAL |
