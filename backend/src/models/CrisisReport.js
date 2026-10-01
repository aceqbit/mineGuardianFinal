import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const reportSchema = new Schema(
  {
    crisisId: { type: Schema.Types.ObjectId, ref: 'Crisis', required: true, unique: true },
    summary: { type: Schema.Types.Mixed, default: {} },
    storagePath: String,
  },
  { timestamps: true, collection: 'crisis_reports' },
);
applyCommon(reportSchema);
export const CrisisReport = mongoose.models.CrisisReport || mongoose.model('CrisisReport', reportSchema);
