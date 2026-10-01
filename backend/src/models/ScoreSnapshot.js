import mongoose from 'mongoose';
import { RISK_BAND } from '../contracts/enums.js';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

/** One snapshot per worker per IST day; the newest one is the current score. */
const scoreSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone', required: true },
    day: { type: String, required: true },
    score: { type: Number, required: true },
    components: { type: Schema.Types.Mixed, default: {} },
    streak: { type: Number, default: 0 },
    xp: { type: Number, default: 0 },
    badges: { type: [{ key: String, earnedAt: Date, _id: false }], default: [] },
    riskBand: { type: String, enum: RISK_BAND, default: 'GREEN' },
    computedAt: { type: Date, default: Date.now },
  },
  { timestamps: true, collection: 'score_snapshots' },
);
scoreSchema.index({ userId: 1, day: 1 }, { unique: true });
scoreSchema.index({ zoneId: 1, day: -1 });
applyCommon(scoreSchema);
export const ScoreSnapshot = mongoose.models.ScoreSnapshot || mongoose.model('ScoreSnapshot', scoreSchema);
