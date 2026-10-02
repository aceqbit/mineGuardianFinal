# Phase 2 payloads and additive routes

The contract v1 names (REST routes, socket events, bus events, enums) are frozen. This file records the **payload shapes** Phase 2 uses and the three routes added after the freeze. Envelope on every socket event: `{ v:1, id, ts, data }`.

## Additive routes (also in `backend/src/contracts/routes.additive.md`)

| Route | Who | Purpose |
|---|---|---|
| `PUT /api/contacts/:id` | admin | Edit a contact. `dialE164` goes through the safety guard (400 `UNSAFE_DIAL_TARGET`). |
| `GET /api/broadcasts/history` | admin, supervisor | Own sent broadcasts with delivered / read / reply counters. |
| `GET /api/broadcasts/replies` | admin, supervisor | Reply inbox. |

## Server → client payloads

| Event | Rooms | `data` |
|---|---|---|
| `compliance:predicted` | zone supervisors, admin, worker | review id, check-in id, verdict, confidence, criticality, emergency flag |
| `compliance:reviewed` | worker, zone supervisors, admin | `{checkInId, reviewId, workerId, finalVerdict, missing[], decidedBy, action}` |
| `score:updated` | the worker | `{score, streak, xp, badges[]}` |
| `leaderboard:updated` | `public:leaderboard` | `{top:[{userId,name,employeeId,zoneId,score,streak,xp,rank}]}` (max 1 per 2 s) |
| `sla:breach` | admin | `{reviewId, checkInId, zoneId, workerId, breachedAt}` |
| `crisis:activated` | everyone | `{crisisId, startedAt, trigger, triggers[], zoneIds[], reason, sosIds[]}` (never the share token) |
| `crisis:updated` | everyone (merge) / staff (accounted) | merge: same shape as activated plus `line`; accounted: `{crisisId, accounted:{workerId,status}}` |
| `crisis:positions` | admin + zone supervisors | `{crisisId, positions:[{userId,name,zoneId,lat,lng,accuracyM,ts,sosId?}]}` (max 1 per 2 s) |
| `crisis:routes` | staff: all routes; worker: own features only | `{crisisId, geojson: FeatureCollection<LineString>}` with the properties listed in CLAUDE.md section 13 |
| `crisis:route_assigned` | the worker | `{crisisId, workerId, rank, exitName, assignedBy}` (followed by a `crisis:routes` with that route) |
| `crisis:resolved` | everyone | `{crisisId, falseAlarm, resolvedAt}` |
| `broadcast:message` | by scope | `{id,text,priority,scope,zoneId,role,senderName,senderRole,createdAt}` |
| `broadcast:stats` | admin + sender | `{broadcastId, targets, delivered, read}` (max 1 per second) |
| `broadcast:reply` | admin + sender | `{id, broadcastId, userId, userName, text, at}` |

## Client → server

| Event | `data` | Ack |
|---|---|---|
| `broadcast:ack` | `{broadcastId, status: DELIVERED \| READ}` | `{ok}` |
| `broadcast:reply` | `{broadcastId?, text(1..280)}` | `{ok}` |

## Responses worth knowing

* `GET /api/crisis/active`: `{active:false}`, or for miners `{active, crisis}`, or for staff `{active, crisis{…, zoneCodes, shareToken, timeline, blockedEdgeIds}, roster[], positions[], routes}`. A supervisor outside the crisis zones gets the miner view.
* `GET /api/contacts`: `dialE164` is returned to admins only.
* Check-in image URLs in `GET /api/compliance/reviews/by-checkin/:id` are signed for 15 minutes.
