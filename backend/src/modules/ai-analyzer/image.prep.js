import crypto from 'node:crypto';
import sharp from 'sharp';
import { sniffImageType } from '../checkins/image-quality.js';

export class AiError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

export class AiBlockedError extends AiError {
  constructor(message = 'The model blocked or returned no output') {
    super('AI_BLOCKED', message);
  }
}

const MAX_BYTES = 8 * 1024 * 1024;
const MIN_SIDE = 480;

/** Auto-rotate, fit within 1536x1536 without enlarging, JPEG q85. Rejects non-JPEG/PNG, > 8 MB and tiny images with IMAGE_INVALID. */
export async function prepare(buffer) {
  if (!buffer || !sniffImageType(buffer)) throw new AiError('IMAGE_INVALID', 'Image must be JPEG or PNG');
  if (buffer.length > MAX_BYTES) throw new AiError('IMAGE_INVALID', 'Image is larger than 8 MB');
  const rotated = await sharp(buffer).rotate().toBuffer({ resolveWithObject: true });
  const { width, height } = rotated.info;
  if (Math.min(width, height) < MIN_SIDE) throw new AiError('IMAGE_INVALID', `Image is too small (min side ${MIN_SIDE}px)`);
  const out = await sharp(rotated.data).resize(1536, 1536, { fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer({ resolveWithObject: true });
  return { buffer: out.data, base64: out.data.toString('base64'), width: out.info.width, height: out.info.height, sha256: crypto.createHash('sha256').update(out.data).digest('hex') };
}
