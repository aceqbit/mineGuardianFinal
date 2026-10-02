import mongoose from 'mongoose';
import { CONTACT_CATEGORY } from '../contracts/enums.js';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

/**
 * displayNumber: the real emergency number, shown to people only.
 * dialE164: the number Twilio actually calls. Never a real emergency number (see contacts.logic.js).
 */
const contactSchema = new Schema(
  {
    category: { type: String, enum: CONTACT_CATEGORY, required: true },
    name: { type: String, required: true },
    displayNumber: { type: String, required: true },
    dialE164: { type: String, required: true },
    notes: String,
    order: { type: Number, default: 0 },
    active: { type: Boolean, default: true },
  },
  { timestamps: true, collection: 'emergency_contacts' },
);
contactSchema.index({ category: 1, name: 1 }, { unique: true });
applyCommon(contactSchema);
export const EmergencyContact = mongoose.models.EmergencyContact || mongoose.model('EmergencyContact', contactSchema);
