import sharp from 'sharp';
import { SERVER_BLUR_MIN, BRIGHTNESS_MIN, BRIGHTNESS_MAX, MIN_SIDE_PX } from './config.js';

/** JPEG (FFD8FF) or PNG (89504E47) by magic bytes. Returns 'jpeg' | 'png' | null. */
export function sniffImageType(buf) {
  if (!buf || buf.length < 4) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpeg';
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return 'png';
  return null;
}

/** Variance of a 3x3 Laplacian ([0,1,0;1,-4,1;0,1,0]) with offset 128 (variance of value-128). */
export function laplacianVariance(gray, w, h) {
  if (w < 3 || h < 3) return 0;
  let sum = 0;
  let sumSq = 0;
  let n = 0;
  for (let y = 1; y < h - 1; y++) {
    const row = y * w;
    for (let x = 1; x < w - 1; x++) {
      const v = gray[row - w + x] + gray[row + x - 1] + gray[row + x + 1] + gray[row + w + x] - 4 * gray[row + x] + 128;
      const d = v - 128;
      sum += d;
      sumSq += d * d;
      n++;
    }
  }
  const mean = sum / n;
  return sumSq / n - mean * mean;
}

/**
 * Server quality check: auto-rotate, size, 512 px grayscale, Laplacian variance, mean brightness.
 * `lenient` (hazards): blur >= SERVER_BLUR_MIN * 0.6 and only brightness < 20 rejects (dark scenes are expected).
 */
export async function analyzeQuality(buffer, { lenient = false } = {}) {
  const rotated = sharp(buffer).rotate();
  const meta = await rotated.clone().metadata();
  // metadata() reports pre-rotation size; take post-rotation size from a raw pass
  const { data, info } = await rotated.clone().grayscale().resize(512, 512, { fit: 'inside', withoutEnlargement: true }).raw().toBuffer({ resolveWithObject: true });
  const blurScore = laplacianVariance(data, info.width, info.height);
  let sum = 0;
  for (let i = 0; i < data.length; i++) sum += data[i];
  const brightness = sum / data.length;
  const swap = (meta.orientation ?? 1) >= 5;
  const width = swap ? meta.height : meta.width;
  const height = swap ? meta.width : meta.height;

  const reasons = [];
  if (Math.min(width, height) < MIN_SIDE_PX) reasons.push('RESOLUTION_LOW');
  if (lenient) {
    if (brightness < 20) reasons.push('TOO_DARK');
    if (blurScore < SERVER_BLUR_MIN * 0.6) reasons.push('BLURRY');
  } else {
    if (brightness < BRIGHTNESS_MIN) reasons.push('TOO_DARK');
    if (brightness > BRIGHTNESS_MAX) reasons.push('TOO_BRIGHT');
    if (blurScore < SERVER_BLUR_MIN) reasons.push('BLURRY');
  }
  return { blurScore, brightness, width, height, pass: reasons.length === 0, reasons };
}
