# Sample photos

Add two real photos here (they are git-tracked on purpose; keep them small, under 1 MB each):

| File | What it should show |
|---|---|
| `worker_full_body.jpg` | One person, head to boots in frame, good light, wearing helmet, hi-vis vest, boots and gloves |
| `hazard_cable.jpg` | A loose or damaged electrical cable across a walkway |

`dev/p1-smoke.js` uses them. If they are missing the script generates synthetic images so it can still run, but the AI steps in
Phase 2 need real photos.

## Blur calibration (do this once, with your phone)

The on-device gate (`mobile/lib/features/worker/data/quality_config.dart`) and the server check
(`backend/src/modules/checkins/config.js`) use different scales, so calibrate both with the same 10 photos.

1. Shoot 5 sharp and 5 deliberately shaky photos of the same scene.
2. Run the app in debug mode and read the `[quality] blurScore=...` lines in the console. Set `blurMinCheckin` and
   `blurMinHazard` halfway between the shaky and sharp groups.
3. Upload the same 10 photos with curl or the app and read the server's `serverQuality.blurScore` from MongoDB (`check_ins`).
   Set `SERVER_BLUR_MIN` halfway between the two groups.
