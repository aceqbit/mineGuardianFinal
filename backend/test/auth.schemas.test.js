import test from 'node:test';
import assert from 'node:assert/strict';
import { signupSchema } from '../src/modules/auth/auth.schemas.js';
import { validatePhone, loginEmailFor } from '../src/modules/auth/auth.service.js';

const valid = () => ({
  role: 'miner',
  fullName: 'Ravi Kumar',
  employeeId: 'min-0150',
  phone: { isoCode: 'IN', dialCode: '91', national: '9876500150' },
  designation: 'Miner',
  experienceYears: 5,
  dateOfJoining: '2020-01-01',
  dob: '1990-05-05',
  bloodGroup: 'O+',
  mineName: 'MG Demo Colliery',
  zoneId: '64b8f0f2f1a2b3c4d5e6f701',
  shift: 'B',
  emergencyContact: { name: 'Sita Kumar', relation: 'Spouse', phone: { isoCode: 'IN', dialCode: '91', national: '9810001234' } },
});

test('valid body passes and employeeId is uppercased', () => {
  const r = signupSchema.parse(valid());
  assert.equal(r.employeeId, 'MIN-0150');
});

test('age 17 fails', () => {
  const b = valid();
  b.dob = new Date(Date.now() - 17 * 365.25 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  assert.throws(() => signupSchema.parse(b));
});

test('phone starting with 0 fails', () => {
  const b = valid();
  b.phone.national = '0876500150';
  assert.throws(() => signupSchema.parse(b));
});

test('role admin fails; unknown keys fail (strict)', () => {
  assert.throws(() => signupSchema.parse({ ...valid(), role: 'admin' }));
  assert.throws(() => signupSchema.parse({ ...valid(), extra: 1 }));
});

test('future joining date fails', () => {
  assert.throws(() => signupSchema.parse({ ...valid(), dateOfJoining: '2999-01-01' }));
});

test('validatePhone: valid Indian mobile ok, wrong country rejected', () => {
  assert.equal(validatePhone({ isoCode: 'IN', dialCode: '91', national: '9876500150' }), '+919876500150');
  assert.equal(validatePhone({ isoCode: 'GB', dialCode: '91', national: '9876500150' }), null);
  assert.equal(validatePhone({ isoCode: 'IN', dialCode: '91', national: '5876500150' }), null);
});

test('loginEmailFor', () => {
  assert.equal(loginEmailFor('+919876500101'), '919876500101@phone.mineguardian.app');
});
