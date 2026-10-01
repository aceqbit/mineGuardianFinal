import mongoose from 'mongoose';
import { applyCommon } from './_plugin.js';

const { Schema } = mongoose;

const reviewSchema = new Schema(
  {
    checkInId: { type: Schema.Types.ObjectId, ref: 'CheckIn', required: true, unique: true },
    workerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone', required: true },
    status: { type: String, enum: ['PENDING_REVIEW', 'DECIDED'], default: 'PENDING_REVIEW' },
    ai: { type: Schema.Types.Mixed, default: {} },
    decision: { type: Schema.Types.Mixed, default: undefined },
    sla: {
      dueAt: Date,
      remindersSent: { type: Number, default: 0 },
      lastReminderAt: Date,
      breached: { type: Boolean, default: false },
      breachedAt: Date,
      streakFrozen: { type: Boolean, default: false },
      compensated: { type: Boolean, default: false },
      compensatedBy: { type: Schema.Types.ObjectId, ref: 'User' },
      escalationAcked: { type: Boolean, default: false },
    },
  },
  { timestamps: true, collection: 'compliance_reviews' },
);
reviewSchema.index({ zoneId: 1, status: 1 });
reviewSchema.index({ 'sla.dueAt': 1 });
applyCommon(reviewSchema);
export const ComplianceReview = mongoose.models.ComplianceReview || mongoose.model('ComplianceReview', reviewSchema);
