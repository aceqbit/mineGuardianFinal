import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

/** Monthly honours. Stars, incentive amount and extra holidays are demo values carried on HONOUR rows. */
const rewardSchema = new Schema(
  {
    month: { type: String, required: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone' },
    key: { type: String, required: true },
    kind: { type: String, enum: ['HONOUR', 'STAR', 'INCENTIVE', 'EXTRA_HOLIDAY'], default: 'HONOUR' },
    title: String,
    rank: Number,
    score: Number,
    stars: { type: Number, default: 0 },
    amountInr: { type: Number, default: 0 },
    extraHolidays: { type: Number, default: 0 },
    demo: { type: Boolean, default: true },
    publishedAt: { type: Date, default: Date.now },
  },
  { timestamps: true, collection: 'rewards' },
);
rewardSchema.index({ month: 1, userId: 1, key: 1 }, { unique: true });
applyCommon(rewardSchema);
export const Reward = mongoose.models.Reward || mongoose.model('Reward', rewardSchema);
