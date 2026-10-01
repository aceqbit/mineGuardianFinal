import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const reportSchema = new Schema(
  {
    type: { type: String, enum: ['DAILY'], default: 'DAILY' },
    day: { type: String, required: true },
    summary: { type: Schema.Types.Mixed, default: {} },
    storagePath: String,
    generatedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    auto: { type: Boolean, default: false },
  },
  { timestamps: true, collection: 'reports' },
);
reportSchema.index({ type: 1, day: -1 });
applyCommon(reportSchema);
export const Report = mongoose.models.Report || mongoose.model('Report', reportSchema);
