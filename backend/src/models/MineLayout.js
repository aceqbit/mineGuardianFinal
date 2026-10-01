import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const layoutSchema = new mongoose.Schema(
  {
    version: { type: Number, required: true, index: true },
    anchor: { lat: Number, lng: Number },
    geojson: { type: mongoose.Schema.Types.Mixed, required: true },
  },
  { timestamps: true, collection: 'layouts' },
);
applyCommon(layoutSchema);
export const MineLayout = mongoose.models.MineLayout || mongoose.model('MineLayout', layoutSchema);
