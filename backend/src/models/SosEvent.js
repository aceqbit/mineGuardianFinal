import mongoose from 'mongoose';
import { SOS_STATUS } from '../contracts/enums.js';
import { applyCommon, pointSchemaDef } from './_plugin.js';

const { Schema } = mongoose;

const sosSchema = new Schema(
  {
    clientId: { type: String, required: true, unique: true },
    workerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone', required: true },
    location: pointSchemaDef,
    accuracyM: Number,
    triggeredAt: Date,
    receivedAt: { type: Date, default: Date.now },
    status: { type: String, enum: SOS_STATUS, default: 'ACTIVE', index: true },
    cancelledAt: Date,
    crisisId: { type: Schema.Types.ObjectId },
  },
  { timestamps: true, collection: 'sos_events' },
);
applyCommon(sosSchema);
export const SosEvent = mongoose.models.SosEvent || mongoose.model('SosEvent', sosSchema);
