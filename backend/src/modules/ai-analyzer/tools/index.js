import { TIMEOUTS } from '../config.js';
import { withTimeout } from '../gemini.client.js';
import { analyzeImageQuality } from './quality.js';
import { detectRoboflow } from './yolo.roboflow.js';
import { detectOnnx } from './yolo.onnx.js';
import { getRequiredPpe, getWorkerHistory, verifyPhotoIntegrity } from './context.js';
import { getHazardProtocol } from './hazard_protocols.js';

export { FUNCTION_DECLARATIONS } from './declarations.js';

async function detectYolo(ctx) {
  const { cfg } = ctx;
  if (cfg.mlMode === 'gemini_only' || cfg.yoloProvider === 'none') return { status: 'unavailable', reason: cfg.mlMode === 'gemini_only' ? 'ML_MODE=gemini_only' : 'YOLO_PROVIDER=none' };
  try {
    if (cfg.yoloProvider === 'onnx') return await detectOnnx({ buffer: ctx.img.buffer, width: ctx.img.width, height: ctx.img.height }, cfg);
    return await detectRoboflow({ base64: ctx.img.base64, width: ctx.img.width, height: ctx.img.height }, cfg);
  } catch (e) {
    return { status: 'error', reason: String(e.message ?? e).slice(0, 200) };
  }
}

/**
 * runTool(name, args, ctx) -> small JSON result with status ok | unavailable | error. 8 s timeout per tool.
 * The image stays in memory in ctx; any image reference other than "current" is ignored.
 */
export async function runTool(name, args = {}, ctx) {
  const run = async () => {
    switch (name) {
      case 'detect_ppe_yolo':
        return detectYolo(ctx);
      case 'analyze_image_quality':
        return analyzeImageQuality({ buffer: ctx.img.buffer });
      case 'get_required_ppe':
        return getRequiredPpe({ zone_id: args.zone_id || ctx.context?.zoneCode }, ctx.context);
      case 'verify_photo_integrity':
        return verifyPhotoIntegrity({ checkin_id: args.checkin_id || ctx.context?.checkInId });
      case 'get_worker_history':
        return getWorkerHistory({ worker_id: args.worker_id || ctx.context?.workerId });
      case 'get_hazard_protocol':
        return getHazardProtocol(args.category || ctx.context?.category);
      default:
        return { status: 'error', reason: `unknown tool ${name}` };
    }
  };
  try {
    return await withTimeout(run(), TIMEOUTS.toolMs, `tool ${name}`);
  } catch (e) {
    return { status: 'error', reason: String(e.message ?? e).slice(0, 200) };
  }
}
