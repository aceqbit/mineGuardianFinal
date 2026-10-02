import mongoose from 'mongoose';
import { BROADCAST_PRIORITY, BROADCAST_SCOPE, ROLE } from '../contracts/enums.js';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const broadcastSchema = new Schema(
  {
    text: { type: String, required: true, maxlength: 280 },
    priority: { type: String, enum: BROADCAST_PRIORITY, default: 'INFO' },
    scope: { type: String, enum: BROADCAST_SCOPE, required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone' },
    role: { type: String, enum: ROLE },
    senderId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    senderName: String,
    senderRole: String,
    targetCount: { type: Number, default: 0 },
    deliveredBy: { type: [Schema.Types.ObjectId], default: [] },
    readBy: { type: [Schema.Types.ObjectId], default: [] },
    replyCount: { type: Number, default: 0 },
    smsSent: { type: Number, default: 0 },
    crisisId: { type: Schema.Types.ObjectId, ref: 'Crisis' },
  },
  { timestamps: true, collection: 'broadcasts' },
);
broadcastSchema.index({ createdAt: -1 });
applyCommon(broadcastSchema);
export const Broadcast = mongoose.models.Broadcast || mongoose.model('Broadcast', broadcastSchema);
