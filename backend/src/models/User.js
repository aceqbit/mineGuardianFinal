import mongoose from 'mongoose';
import { ROLE, USER_STATUS, SHIFT } from '../contracts/enums.js';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const userSchema = new Schema(
  {
    firebaseUid: { type: String, required: true, unique: true },
    role: { type: String, enum: ROLE, required: true },
    status: { type: String, enum: USER_STATUS, default: 'active' },
    fullName: { type: String, required: true, trim: true },
    employeeId: { type: String, required: true, unique: true, uppercase: true, trim: true },
    phone: {
      isoCode: String,
      dialCode: String,
      national: String,
      e164: { type: String, required: true, unique: true },
    },
    loginEmail: { type: String, required: true, unique: true, lowercase: true, trim: true },
    designation: String,
    experienceYears: Number,
    dateOfJoining: Date,
    dob: Date,
    bloodGroup: String,
    mineName: String,
    zoneId: {
      type: Schema.Types.ObjectId,
      ref: 'Zone',
      required: function req() {
        return this.role === 'miner' || this.role === 'supervisor';
      },
    },
    shift: { type: String, enum: SHIFT },
    emergencyContact: { name: String, relation: String, e164: String },
    address: String,
    fcmTokens: { type: [String], default: [] },
    lastLoginAt: Date,
  },
  { timestamps: true, collection: 'users' },
);

userSchema.methods.toPublic = function toPublic() {
  const o = this.toJSON();
  delete o.fcmTokens;
  delete o.loginEmail;
  return o;
};

applyCommon(userSchema);
export const User = mongoose.models.User || mongoose.model('User', userSchema);
