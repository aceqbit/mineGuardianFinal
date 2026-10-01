import PDFDocument from 'pdfkit';

const IST = (d) => (d ? new Date(new Date(d).getTime() + 5.5 * 3600 * 1000).toISOString().replace('T', ' ').slice(0, 19) + ' IST' : '—');

/** Post-crisis A4 report. Returns a Buffer. */
export async function buildCrisisReportPdf(s) {
  const doc = new PDFDocument({ size: 'A4', margin: 40, info: { Title: `Crisis report ${s.crisisId}`, Author: 'Mine Guardian' } });
  const chunks = [];
  doc.on('data', (c) => chunks.push(c));
  const done = new Promise((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));
  const h2 = (t) => doc.moveDown(0.8).font('Helvetica-Bold').fontSize(12).fillColor('#0B1220').text(t).moveDown(0.2).font('Helvetica').fontSize(10).fillColor('#1f2937');
  const line = (k, v) => doc.font('Helvetica-Bold').text(`${k}: `, { continued: true }).font('Helvetica').text(String(v ?? '—'));

  doc.rect(0, 0, doc.page.width, 56).fill('#B91C1C');
  doc.fillColor('#ffffff').fontSize(16).font('Helvetica-Bold').text('Mine Guardian  ·  Crisis report', 40, 18);
  doc.fillColor('#1f2937').fontSize(10).y = 72;

  h2('Summary');
  line('Started', IST(s.startedAt));
  line('Resolved', IST(s.resolvedAt));
  line('Duration', `${s.durationMin} min`);
  line('Zones', s.zones.map((z) => z.code).join(', '));
  line('Triggers', s.triggers.map((t) => t.type).join(', '));
  line('Outcome', s.resolution.falseAlarm ? 'False alarm' : 'Resolved');
  line('Resolution note', s.resolution.note);
  line('GPS pings recorded', s.gpsPings);

  h2('Accounted for');
  const a = s.accounted;
  line('Total', `${a.total}  (safe ${a.SAFE}, missing ${a.MISSING}, injured ${a.INJURED}, unknown ${a.UNKNOWN})`);
  for (const r of s.roster) doc.text(`• ${r.name} (${r.employeeId}): ${r.status}`, { indent: 8 });

  h2('Timeline');
  for (const t of s.timeline) doc.text(`${IST(t.at)}  ${t.text}`, { indent: 8 });

  doc.end();
  return done;
}
