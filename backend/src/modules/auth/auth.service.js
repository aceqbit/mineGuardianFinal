import { parsePhoneNumberFromString } from 'libphonenumber-js/max';
import { AppError } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { firebaseAuth } from '../../core/firebase.js';
import { LOGIN_EMAIL_DOMAIN } from '../../contracts/enums.js';
import { User } from '../../models/User.js';
import { Zone } from '../../models/Zone.js';

export const loginEmailFor = (e164) => `${e164.replace(/\D/g, '')}@${LOGIN_EMAIL_DOMAIN}`;

/** Returns e164 when valid mobile for isoCode, else null. */
export function validatePhone({ isoCode, dialCode, national }) {
  const e164 = `+${dialCode}${national}`;
  const p = parsePhoneNumberFromString(e164);
  if (!p || !p.isValid()) return null;
  const type = p.getType();
  if (type !== 'MOBILE' && type !== 'FIXED_LINE_OR_MOBILE') return null;
  if (p.country !== isoCode) return null;
  return e164;
}

export async function signup(req) {
  const b = req.body;
  const e164 = validatePhone(b.phone);
  if (!e164) throw new AppError(400, 'INVALID_PHONE', 'Not a valid mobile number', { path: 'phone' });
  const emergencyE164 = validatePhone(b.emergencyContact.phone);
  if (!emergencyE164 || emergencyE164 === e164) {
    throw new AppError(400, 'INVALID_EMERGENCY_PHONE', 'Emergency contact needs a different valid mobile number', { path: 'emergencyContact.phone' });
  }
  const loginEmail = loginEmailFor(e164);
  if (!req.firebase?.email || req.firebase.email.toLowerCase() !== loginEmail) {
    throw new AppError(400, 'PHONE_TOKEN_MISMATCH', 'Phone number does not match this account', { path: 'phone' });
  }
  if (await User.exists({ firebaseUid: req.firebase.uid })) {
    throw new AppError(409, 'ALREADY_REGISTERED', 'This account already has a profile');
  }
  const zone = await Zone.findById(b.zoneId);
  if (!zone) throw new AppError(400, 'ZONE_NOT_FOUND', 'Zone not found', { path: 'zoneId' });

  let user;
  try {
    user = await User.create({
      firebaseUid: req.firebase.uid,
      role: b.role,
      status: 'active',
      fullName: b.fullName,
      employeeId: b.employeeId,
      phone: { isoCode: b.phone.isoCode, dialCode: b.phone.dialCode, national: b.phone.national, e164 },
      loginEmail,
      designation: b.designation,
      experienceYears: b.experienceYears,
      dateOfJoining: new Date(b.dateOfJoining),
      dob: new Date(b.dob),
      bloodGroup: b.bloodGroup,
      mineName: b.mineName,
      zoneId: zone._id,
      shift: b.shift,
      emergencyContact: { name: b.emergencyContact.name, relation: b.emergencyContact.relation, e164: emergencyE164 },
      address: b.address,
    });
  } catch (err) {
    if (err?.code === 11000) {
      const key = Object.keys(err.keyPattern || err.keyValue || {})[0] || '';
      if (key.startsWith('employeeId')) throw new AppError(409, 'DUPLICATE', 'This employee ID is already registered', { field: 'employeeId', path: 'employeeId' });
      if (key.startsWith('phone') || key.startsWith('loginEmail')) throw new AppError(409, 'DUPLICATE', 'This phone number is already registered', { field: 'phone', path: 'phone' });
    }
    throw err;
  }
  if (b.role === 'supervisor') await Zone.updateOne({ _id: zone._id }, { $addToSet: { supervisorIds: user._id } });
  await firebaseAuth().setCustomUserClaims(req.firebase.uid, { role: b.role });
  await audit(user, 'USER_SIGNUP', 'user', user._id, { role: b.role, zone: zone.code });
  return user;
}
