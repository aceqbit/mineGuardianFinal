import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const pingSchema = new Schema(
  {
    crisisId: { type: Schema.Types.ObjectId, ref: 'Crisis', required: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    lat: Number,
    lng: Number,
    accuracyM: Number,
    ts: Date,
  },
  { timestamps: false, collection: 'gps_pings' },
);
pingSchema.index({ crisisId: 1, userId: 1, ts: 1 });
applyCommon(pingSchema);
export const GpsPing = mongoose.models.GpsPing || mongoose.model('GpsPing', pingSchema);
