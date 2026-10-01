import { Router } from 'express';
import { Crisis } from '../../models/Crisis.js';
import { Zone } from '../../models/Zone.js';
import { User } from '../../models/User.js';
import { asyncHandler } from '../../core/errors.js';
import { accountedCounts, buildRoster } from '../crisis/crisis.logic.js';

const router = Router();
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const IST = (d) => new Date(new Date(d).getTime() + 5.5 * 3600 * 1000).toISOString().replace('T', ' ').slice(0, 16) + ' IST';

/** Self-contained page: inline CSS, no external scripts, refreshes itself every 10 s. */
export function trackPage({ startedAt, zones, counts, reason }) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="10"><title>Mine Guardian — emergency status</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#0B1220;color:#f8fafc}header{background:#B91C1C;padding:16px 20px;font-weight:700;font-size:18px}main{padding:20px;max-width:560px;margin:auto}.card{background:#111c33;border-radius:12px;padding:16px;margin-bottom:12px}.row{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid #1f2d4d}.row:last-child{border:0}small{color:#94a3b8}.big{font-size:28px;font-weight:800}</style></head>
<body><header>Mine Guardian — emergency in progress</header><main>
<div class="card"><div class="big">Active</div><small>Since ${esc(IST(startedAt))}</small><p>${esc(reason)}</p><small>Zones: ${esc(zones.join(', '))}</small></div>
<div class="card"><div class="row"><span>Workers in affected zones</span><b>${counts.total}</b></div><div class="row"><span>Safe</span><b>${counts.SAFE}</b></div><div class="row"><span>Missing</span><b>${counts.MISSING}</b></div><div class="row"><span>Injured</span><b>${counts.INJURED}</b></div><div class="row"><span>Not yet accounted for</span><b>${counts.UNKNOWN}</b></div></div>
<small>This page updates every 10 seconds. It shows counts only. Keep your phone on.</small></main></body></html>`;
}

const expired = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Link expired</title></head><body style="font-family:system-ui,sans-serif;padding:32px"><h2>This tracking link has expired</h2><p>The emergency has ended or the link is not valid.</p></body></html>';

router.get(
  '/track/:token',
  asyncHandler(async (req, res) => {
    res.set('Cache-Control', 'no-store');
    const token = String(req.params.token);
    const crisis = /^[A-Za-z0-9_-]{24}$/.test(token) ? await Crisis.findOne({ shareToken: token, status: 'ACTIVE' }) : null;
    if (!crisis) return res.status(404).type('html').send(expired);
    const [zones, miners] = await Promise.all([Zone.find({ _id: { $in: crisis.zoneIds } }), User.find({ role: 'miner', status: 'active', zoneId: { $in: crisis.zoneIds } })]);
    const counts = accountedCounts(buildRoster(miners, crisis.accounted));
    return res.type('html').send(trackPage({ startedAt: crisis.startedAt, zones: zones.map((z) => z.code), counts, reason: crisis.reason }));
  }),
);

export default { name: 'public-track', basePath: '/public', router };
