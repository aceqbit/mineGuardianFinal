import PDFDocument from 'pdfkit';
import sharp from 'sharp';

const IST = (d) => (d ? new Date(new Date(d).getTime() + 5.5 * 3600 * 1000).toISOString().replace('T', ' ').slice(0, 19) + ' IST' : '—');
const LABEL = { HELMET: 'Helmet', CAP_LAMP: 'Cap lamp', REFLECTIVE_VEST: 'Reflective vest', SAFETY_BOOTS: 'Safety boots', GLOVES: 'Gloves', SELF_RESCUER: 'Self-rescuer', DUST_MASK: 'Dust mask', EAR_PROTECTION: 'Ear protection', EYE_PROTECTION: 'Eye protection', GAS_DETECTOR: 'Gas detector' };
const FLAG_TEXT = {
  STALE_PHOTO: 'Photo was taken long before upload', CLOCK_SKEW: 'Phone clock differs from the server', NO_EXIF: 'Gallery photo with no capture time', DUPLICATE_HASH: 'Exact photo seen before',
  OUTSIDE_ZONE: 'Taken outside the worker zone', LOW_GPS_ACCURACY: 'GPS fix weak or missing', OUT_OF_SHIFT: 'Taken outside the shift window', OFFLINE_DELAYED: 'Queued offline before upload', GALLERY_SOURCE: 'Picked from the gallery',
};

/** Compliance report as an A4 PDF (pdfkit). Returns a Buffer. */
export async function buildReviewPdf({ review, checkIn, worker, zone, photo, deciderName }) {
  const doc = new PDFDocument({ size: 'A4', margin: 40, info: { Title: `Compliance report ${review._id}`, Author: 'Mine Guardian' } });
  const chunks = [];
  doc.on('data', (c) => chunks.push(c));
  const done = new Promise((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));
  const ai = review.ai ?? {};
  const dec = review.decision;
  const W = doc.page.width - 80;

  const h2 = (t) => { doc.moveDown(0.8).fontSize(12).fillColor('#0B1220').font('Helvetica-Bold').text(t).moveDown(0.2).font('Helvetica').fontSize(10).fillColor('#1f2937'); };
  const line = (k, v) => doc.font('Helvetica-Bold').text(`${k}: `, { continued: true }).font('Helvetica').text(String(v ?? '—'));
  const bullets = (arr) => (arr?.length ? arr.forEach((x) => doc.text(`• ${x}`, { indent: 8 })) : doc.text('—', { indent: 8 }));

  doc.rect(0, 0, doc.page.width, 56).fill('#0B1220');
  doc.fillColor('#F59E0B').fontSize(16).font('Helvetica-Bold').text('Mine Guardian', 40, 16, { continued: true }).fillColor('#ffffff').font('Helvetica').text(`  ·  Compliance report  ·  ${String(review._id).slice(-8)}`);
  doc.fillColor('#1f2937').font('Helvetica').fontSize(10).y = 72;

  h2('Worker, zone and shift');
  line('Worker', `${worker?.fullName ?? '—'} (${worker?.employeeId ?? '—'})`);
  line('Zone', `${zone?.code ?? '—'} · ${zone?.name ?? ''}`);
  line('Shift', worker?.shift ?? checkIn?.shift ?? '—');

  if (photo) {
    try {
      const small = await sharp(photo).rotate().resize({ width: 600, withoutEnlargement: true }).jpeg({ quality: 70 }).toBuffer();
      h2('Photo');
      doc.image(small, { fit: [220, 280] });
      doc.moveDown(0.5);
    } catch {
      /* skip an unreadable photo */
    }
  }

  h2('Verdict');
  const crit = ai.criticality ?? {};
  line('AI verdict', `${ai.overallVerdict ?? '—'} (confidence ${ai.overallConfidence ?? '—'})`);
  line('Criticality', `${crit.level ?? '—'} ${crit.score ?? ''}/100`);
  if (crit.drivers?.length) line('Drivers', crit.drivers.join('; '));
  if (ai.emergency?.detected || ai.emergency?.possible) line('Emergency', `${ai.emergency.detected ? 'DETECTED' : 'possible'} · ${ai.emergency.type} · ${ai.emergency.evidence ?? ''}`);

  h2('Checklist');
  const decided = new Map((dec?.items ?? []).map((i) => [i.key, i.status]));
  const colX = [40, 175, 235, 395, 480];
  doc.font('Helvetica-Bold');
  ['Item', 'Required', 'AI status (conf, source)', 'Final'].forEach((t, i) => doc.text(t, colX[i], doc.y, { width: colX[i + 1] - colX[i] - 4, continued: i < 3 }));
  doc.font('Helvetica');
  for (const it of ai.items ?? []) {
    const y = doc.y + 2;
    doc.text(LABEL[it.key] ?? it.key, colX[0], y, { width: 130 });
    doc.text(it.required ? 'Yes' : 'No', colX[1], y, { width: 56 });
    doc.text(`${it.status} (${it.confidence}, ${it.source ?? 'gemini'})`, colX[2], y, { width: 156 });
    doc.text(decided.get(it.key) ?? (it.required ? '—' : 'n/a'), colX[3], y, { width: 80 });
    doc.y = y + 14;
  }
  doc.x = 40;

  h2('Timestamps and integrity');
  line('Captured', IST(checkIn?.capturedAt));
  line('Uploaded', IST(checkIn?.uploadStartedAt));
  line('Received', IST(checkIn?.receivedAt));
  line('Clock skew', `${checkIn?.clockSkewSec ?? 0} s`);
  line('Source', checkIn?.source);
  if (checkIn?.integrityFlags?.length) bullets(checkIn.integrityFlags.map((f) => `${f}: ${FLAG_TEXT[f] ?? ''}`));

  h2('AI summary');
  doc.text(ai.summary ?? '—', { width: W });
  h2('Observations'); bullets(ai.report?.observations);
  h2('Risks'); bullets(ai.report?.risks);
  h2('Recommended actions'); bullets(ai.report?.recommendedActions);
  if (ai.conflicts?.length) { h2('YOLO vs Gemini conflicts'); bullets(ai.conflicts); }
  if (ai.limitations?.length) { h2('Limitations'); bullets(ai.limitations); }

  h2('Model trace');
  line('Model', ai.model);
  line('YOLO provider', ai.yoloProvider);
  line('Latency', `${ai.latencyMs ?? '—'} ms`);
  line('Tools called', (ai.toolTrace ?? []).map((t) => `${t.name} (${t.calledBy ?? 'model'})`).join(', ') || '—');

  h2('Decision');
  if (dec) {
    line('Decided by', deciderName ?? '—');
    line('At', IST(dec.decidedAt));
    line('Action', `${dec.action}${dec.escalationLevel ? ` (${dec.escalationLevel})` : ''}`);
    line('Final verdict', dec.finalVerdict);
    line('Agreed with AI', dec.agreedWithAi ? 'Yes' : 'No');
    line('Note', dec.note || '—');
  } else {
    doc.text('Pending supervisor decision.');
  }
  doc.end();
  return done;
}
