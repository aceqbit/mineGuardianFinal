import mongoose from 'mongoose';
import { CHECKIN_STATUS, INTEGRITY_FLAG, SHIFT } from '../contracts/enums.js';
import { applyCommon, pointSchemaDef } from './_plugin.js';

const { Schema } = mongoose;
const quality = { blurScore: Number, brightness: Number, width: Number, height: Number };

const checkInSchema = new Schema(
  {
    workerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    zoneId: { type: Schema.Types.ObjectId, ref: 'Zone', required: true },
    shift: { type: String, enum: SHIFT },
    clientId: { type: String, required: true, unique: true },
    storagePath: { type: String, required: true },
    source: { type: String, enum: ['camera', 'gallery'], default: 'camera' },
    attempt: { type: Number, default: 1 },
    capturedAt: Date,
    exifTakenAt: Date,
    queuedAt: Date,
    uploadStartedAt: Date,
    receivedAt: { type: Date, default: Date.now },
    clockSkewSec: Number,
    location: pointSchemaDef,
    accuracyM: Number,
    insideZone: Boolean,
    withinShift: Boolean,
    clientQuality: {
      ...quality,
      poseChecked: Boolean,
      poseOk: Boolean,
      missingLandmarks: [String],
    },
    serverQuality: { ...quality, pass: Boolean },
    sha256: String,
    integrityFlags: [{ type: String, enum: INTEGRITY_FLAG }],
    status: { type: String, enum: CHECKIN_STATUS, default: 'RECEIVED' },
    reviewId: { type: Schema.Types.ObjectId },
  },
  { timestamps: true, collection: 'check_ins' },
);
checkInSchema.index({ workerId: 1, createdAt: -1 });
checkInSchema.index({ workerId: 1, sha256: 1 });
checkInSchema.index({ zoneId: 1, createdAt: -1 });
checkInSchema.index({ location: '2dsphere' }, { sparse: true });
applyCommon(checkInSchema);
export const CheckIn = mongoose.models.CheckIn || mongoose.model('CheckIn', checkInSchema);
