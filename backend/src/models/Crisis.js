import mongoose from 'mongoose';
import { ACCOUNTED_STATUS, CRISIS_STATUS, CRISIS_TRIGGER } from '../contracts/enums.js';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const trigger = { _id: false, type: { type: String, enum: CRISIS_TRIGGER, required: true }, refId: String, by: String, at: Date };

const crisisSchema = new Schema(
  {
    status: { type: String, enum: CRISIS_STATUS, default: 'ACTIVE' },
    startedAt: { type: Date, default: Date.now },
    resolvedAt: Date,
    /** First trigger, kept as `trigger` so the Phase 1 admin overview keeps working. */
    trigger: { type: new Schema(trigger, { _id: false }) },
    triggers: [trigger],
    zoneIds: [{ type: Schema.Types.ObjectId, ref: 'Zone' }],
    reason: String,
    sosIds: [{ type: Schema.Types.ObjectId, ref: 'SosEvent' }],
    shareToken: { type: String, index: true, sparse: true },
    timeline: [{ _id: false, at: Date, text: String }],
    accounted: {
      type: [{ _id: false, workerId: { type: Schema.Types.ObjectId, ref: 'User' }, status: { type: String, enum: ACCOUNTED_STATUS }, by: { type: Schema.Types.ObjectId, ref: 'User' }, at: Date }],
      default: [],
    },
    blockedEdgeIds: [String],
    routesComputedAt: Date,
    resolution: { falseAlarm: Boolean, note: String, checklist: { allAccounted: Boolean, hazardsContained: Boolean }, resolvedBy: { type: Schema.Types.ObjectId, ref: 'User' } },
  },
  { timestamps: true, collection: 'crises' },
);
crisisSchema.index({ status: 1, startedAt: -1 });
applyCommon(crisisSchema);
export const Crisis = mongoose.models.Crisis || mongoose.model('Crisis', crisisSchema);
