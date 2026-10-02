// Seeds the emergency contacts. displayNumber is what people see; dialE164 is what Twilio dials and must be a team member's verified phone.
// The demo default is the seeded admin's phone. Override with DEMO_DIAL_E164. Every value goes through assertSafeDialTarget.
import { EmergencyContact } from '../src/models/EmergencyContact.js';
import { assertSafeDialTarget } from '../src/modules/contacts/contacts.logic.js';

const CONTACTS = [
  { category: 'POLICE', name: 'Police control room', displayNumber: '100 / 112', notes: 'National emergency line (display only)' },
  { category: 'FIRE', name: 'Fire service', displayNumber: '101', notes: 'Display only' },
  { category: 'MINE_RESCUE', name: 'Mine rescue station', displayNumber: '1070', notes: 'State disaster response (display only)' },
  { category: 'AMBULANCE', name: 'Ambulance', displayNumber: '108', notes: 'Display only' },
  { category: 'DISTRICT_MINING_AUTHORITY', name: 'District mining authority', displayNumber: '0326-2200000', notes: 'Demo number' },
];

export async function seedContacts(dial = process.env.DEMO_DIAL_E164 || '+919876500001') {
  assertSafeDialTarget(dial);
  let order = 0;
  for (const c of CONTACTS) {
    await EmergencyContact.updateOne({ category: c.category, name: c.name }, { $set: { ...c, dialE164: dial, order: order++, active: true } }, { upsert: true });
  }
  return CONTACTS.length;
}
