import mongoose from 'mongoose';
import { HAZARD_CATEGORY, HAZARD_STATUS } from '../contracts/enums.js';
import { applyCommon, pointSchemaDef } from './_plugin.js';

const { Schema } = mongoose;

const hazardSchema = new Schema(
  {
    clientId: { type: String, required: true, unique: true },
    reporterId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone', required: true },
    category: { type: String, enum: HAZARD_CATEGORY, required: true },
    storagePath: { type: String, required: true },
    location: pointSchemaDef,
    accuracyM: Number,
    capturedAt: Date,
    queuedAt: Date,
    receivedAt: { type: Date, default: Date.now },
    status: { type: String, enum: HAZARD_STATUS, default: 'OPEN' },
    acknowledgedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    acknowledgedAt: Date,
    closedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    closedAt: Date,
    closeNote: String,
    ai: { type: Schema.Types.Mixed, default: undefined },
  },
  { timestamps: true, collection: 'hazards' },
);
hazardSchema.index({ zoneId: 1, status: 1, createdAt: -1 });
hazardSchema.index({ location: '2dsphere' }, { sparse: true });
applyCommon(hazardSchema);
export const Hazard = mongoose.models.Hazard || mongoose.model('Hazard', hazardSchema);
