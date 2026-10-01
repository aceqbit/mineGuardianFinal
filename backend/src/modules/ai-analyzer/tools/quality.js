import sharp from 'sharp';
import { laplacianVariance } from '../../checkins/image-quality.js';

/** analyze_image_quality: size, blur (Laplacian variance), brightness, contrast, clipped fraction, ok/poor with reasons. */
export async function analyzeImageQuality({ buffer }) {
  const meta = await sharp(buffer).metadata();
  const { data, info } = await sharp(buffer).rotate().grayscale().resize(512, 512, { fit: 'inside', withoutEnlargement: true }).raw().toBuffer({ resolveWithObject: true });
  const blurScore = laplacianVariance(data, info.width, info.height);
  let sum = 0, sumSq = 0, clipped = 0;
  for (let i = 0; i < data.length; i++) {
    const v = data[i];
    sum += v;
    sumSq += v * v;
    if (v < 8 || v > 247) clipped++;
  }
  const n = data.length;
  const brightness = sum / n;
  const contrast = Math.sqrt(Math.max(0, sumSq / n - brightness * brightness));
  const clippedPct = clipped / n;
  const reasons = [];
  if (blurScore < 40) reasons.push('blurred');
  if (brightness < 40) reasons.push('too dark');
  if (brightness > 220) reasons.push('too bright');
  if (clippedPct > 0.3) reasons.push('clipped exposure');
  return {
    status: 'ok', width: meta.width, height: meta.height, blurScore: Math.round(blurScore * 10) / 10, brightness: Math.round(brightness * 10) / 10,
    contrast: Math.round(contrast * 10) / 10, clippedPct: Math.round(clippedPct * 1000) / 1000, verdict: reasons.length ? 'poor' : 'ok', reasons,
  };
}
