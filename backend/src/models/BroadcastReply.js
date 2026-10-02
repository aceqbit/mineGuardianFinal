import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const replySchema = new Schema(
  {
    broadcastId: { type: Schema.Types.ObjectId, ref: 'Broadcast' },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    userName: String,
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone' },
    text: { type: String, required: true, maxlength: 280 },
  },
  { timestamps: true, collection: 'broadcast_replies' },
);
replySchema.index({ createdAt: -1 });
replySchema.index({ broadcastId: 1, createdAt: 1 });
applyCommon(replySchema);
export const BroadcastReply = mongoose.models.BroadcastReply || mongoose.model('BroadcastReply', replySchema);
