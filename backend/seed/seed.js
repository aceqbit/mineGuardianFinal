// Idempotent seed: zones, layout v1, 16 demo accounts (Firebase + Mongo). `--reset` wipes collections first.
import { env } from '../src/config/env.js';
import { connectDb, disconnectDb } from '../src/core/db.js';
import { firebaseAuth } from '../src/core/firebase.js';
import { maskPhone } from '../src/core/logger.js';
import { buildLayout } from './build_layout.js';
import { User } from '../src/models/User.js';
import { Zone } from '../src/models/Zone.js';
import { MineLayout } from '../src/models/MineLayout.js';
import { CheckIn } from '../src/models/CheckIn.js';
import { Hazard } from '../src/models/Hazard.js';
import { SosEvent } from '../src/models/SosEvent.js';
import { ComplianceReview } from '../src/models/ComplianceReview.js';
import { AuditLog } from '../src/models/AuditLog.js';
import { LOGIN_EMAIL_DOMAIN } from '../src/contracts/enums.js';

const MINE = 'MG Demo Colliery';
const SHIFT_WINDOWS = [
  { shift: 'A', start: '06:00', end: '14:00' },
  { shift: 'B', start: '14:00', end: '22:00' },
  { shift: 'C', start: '22:00', end: '06:00' },
];
const ZONES = [
  { code: 'Z-A', name: 'Zone A — West Panel', requiredPpe: ['HELMET', 'CAP_LAMP', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES', 'SELF_RESCUER'] },
  { code: 'Z-B', name: 'Zone B — Central Panel', requiredPpe: ['HELMET', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES'] },
  { code: 'Z-C', name: 'Zone C — East Panel', requiredPpe: ['HELMET', 'CAP_LAMP', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES', 'SELF_RESCUER', 'DUST_MASK', 'EAR_PROTECTION', 'EYE_PROTECTION'] },
];
const MINER_NAMES = [
  'Ravi Kumar', 'Suresh Yadav', 'Mohan Singh', 'Anil Mahato', 'Dinesh Oraon', 'Prakash Munda',
  'Rakesh Sharma', 'Santosh Paswan', 'Vijay Thakur', 'Manoj Rajak', 'Arjun Tudu', 'Bikash Ghosh',
];
const SUP_NAMES = ['Ramesh Prasad', 'Sunil Banerjee', 'Ajay Verma'];
const BLOOD = ['A+', 'B+', 'O+', 'AB+', 'O-', 'B-'];

const pad = (n, w = 4) => String(n).padStart(w, '0');

function polygonOf(geojson, code) {
  return geojson.features.find((f) => f.properties.kind === 'zone' && f.properties.code === code).geometry;
}

async function ensureFirebaseUser(email, password, role) {
  const auth = firebaseAuth();
  let u;
  try {
    u = await auth.getUserByEmail(email);
    await auth.updateUser(u.uid, { password });
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    u = await auth.createUser({ email, password, emailVerified: true });
  }
  await auth.setCustomUserClaims(u.uid, { role });
  return u.uid;
}

async function main() {
  const reset = process.argv.includes('--reset');
  await connectDb(env.MONGODB_URI);
  if (reset) {
    for (const M of [User, Zone, MineLayout, CheckIn, Hazard, SosEvent, ComplianceReview, AuditLog]) await M.deleteMany({});
    console.log('Collections wiped');
  }
  await Promise.all([User.init(), Zone.init(), CheckIn.init(), Hazard.init(), SosEvent.init(), ComplianceReview.init()]);

  const geojson = buildLayout({ lat: env.DEMO_ANCHOR_LAT, lng: env.DEMO_ANCHOR_LNG });
  await MineLayout.updateOne(
    { version: 1 },
    { $set: { version: 1, anchor: { lat: env.DEMO_ANCHOR_LAT, lng: env.DEMO_ANCHOR_LNG }, geojson } },
    { upsert: true },
  );

  const zones = {};
  for (const z of ZONES) {
    zones[z.code] = await Zone.findOneAndUpdate(
      { code: z.code },
      { $set: { ...z, mineName: MINE, polygon: polygonOf(geojson, z.code), shiftWindows: SHIFT_WINDOWS } },
      { upsert: true, new: true },
    );
  }

  const people = [];
  people.push({ role: 'admin', name: 'Anita Deshmukh', phone: '9876500001', password: 'Admin1', employeeId: 'ADM-0001', designation: 'Supervisor', zone: null });
  ZONES.forEach((z, i) =>
    people.push({ role: 'supervisor', name: SUP_NAMES[i], phone: `98765000${11 + i}`, password: 'Super1', employeeId: `SUP-${pad(11 + i)}`, designation: 'Mining Sirdar', zone: z.code }),
  );
  MINER_NAMES.forEach((n, i) =>
    people.push({
      role: 'miner', name: n, phone: `98765001${pad(1 + i, 2)}`, password: 'Miner1', employeeId: `MIN-${pad(101 + i)}`,
      designation: 'Miner', zone: ZONES[Math.floor(i / 4)].code, shift: i % 2 === 0 ? 'A' : 'B',
    }),
  );

  const table = [];
  for (const p of people) {
    const e164 = `+91${p.phone}`;
    const loginEmail = `91${p.phone}@${LOGIN_EMAIL_DOMAIN}`;
    const uid = await ensureFirebaseUser(loginEmail, p.password, p.role);
    const zone = p.zone ? zones[p.zone] : null;
    const idx = people.indexOf(p);
    const doc = {
      firebaseUid: uid, role: p.role, status: 'active', fullName: p.name, employeeId: p.employeeId,
      phone: { isoCode: 'IN', dialCode: '91', national: p.phone, e164 }, loginEmail,
      designation: p.designation, experienceYears: 3 + (idx % 12), dateOfJoining: new Date(2018 + (idx % 6), idx % 12, 5),
      dob: new Date(1980 + (idx % 15), idx % 12, 10), bloodGroup: BLOOD[idx % BLOOD.length], mineName: MINE,
      zoneId: zone?._id, shift: p.shift || (p.role === 'supervisor' ? 'A' : undefined),
      emergencyContact: { name: `${p.name.split(' ')[0]}'s family`, relation: 'Spouse', e164: `+91981000${pad(idx, 4)}` },
    };
    const u = await User.findOneAndUpdate({ firebaseUid: uid }, { $set: doc }, { upsert: true, new: true, setDefaultsOnInsert: true });
    if (p.role === 'supervisor') await Zone.updateOne({ _id: zone._id }, { $addToSet: { supervisorIds: u._id } });
    table.push({ role: p.role, id: u.id, employeeId: p.employeeId, phone: maskPhone(e164), zone: p.zone || '-', password: p.password });
  }
  console.table(table);
  console.log(`Seed complete: ${ZONES.length} zones, layout v1, ${people.length} users`);
  await disconnectDb();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
