// AI analyser configuration. Reads process.env directly so the CLI and tests work without MongoDB/Firebase settings.
import 'dotenv/config';

export const DEFAULT_REQUIRED_PPE = Object.freeze(['HELMET', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES']);

export const THRESHOLDS = Object.freeze({
  minItemConfidence: 0.6,
  emergencyDetectConf: 0.8,
  emergencyPossibleConf: 0.5,
  hazardCriticalConf: 0.75,
  yoloPositive: 0.5,
  yoloStrong: 0.8,
  yoloFallPossible: 0.7,
  confCapNoYolo: 0.85,
  confCapNotDetectable: 0.9,
  maxItemConfidence: 0.99,
});

export const TIMEOUTS = Object.freeze({ callMs: 20_000, totalMs: 30_000, toolMs: 8_000, stageABudgetMs: 15_000, retries: 2, retryDelaysMs: [1000, 3000] });

/** Criticality weights per PPE key. */
export const PPE_WEIGHTS = Object.freeze({
  HELMET: 30, SELF_RESCUER: 30, CAP_LAMP: 20, GAS_DETECTOR: 20, SAFETY_BOOTS: 15, REFLECTIVE_VEST: 12, DUST_MASK: 10, GLOVES: 8, EAR_PROTECTION: 5, EYE_PROTECTION: 5,
});

export const PPE_LABEL = Object.freeze({
  HELMET: 'Helmet', CAP_LAMP: 'Cap lamp', REFLECTIVE_VEST: 'Reflective vest', SAFETY_BOOTS: 'Safety boots', GLOVES: 'Gloves',
  SELF_RESCUER: 'Self-rescuer', DUST_MASK: 'Dust mask', EAR_PROTECTION: 'Ear protection', EYE_PROTECTION: 'Eye protection', GAS_DETECTOR: 'Gas detector',
});

export const HAZARD_BASE_SCORE = Object.freeze({ LOW: 25, MEDIUM: 55, CRITICAL: 90 });
export const REPEAT_OFFENDER_BONUS = 10;
export const INTEGRITY_BONUS = 15;
export const INTEGRITY_BONUS_FLAGS = Object.freeze(['DUPLICATE_HASH', 'STALE_PHOTO', 'OUTSIDE_ZONE']);

export const LEVEL_BANDS = Object.freeze([
  { level: 'NONE', min: 0, max: 0 },
  { level: 'LOW', min: 1, max: 19 },
  { level: 'MEDIUM', min: 20, max: 44 },
  { level: 'HIGH', min: 45, max: 69 },
  { level: 'CRITICAL', min: 70, max: 100 },
]);

export function levelFor(score) {
  const s = Math.max(0, Math.min(100, Math.round(score)));
  return LEVEL_BANDS.find((b) => s >= b.min && s <= b.max).level;
}

export function aiConfig(env = process.env) {
  return Object.freeze({
    apiKey: env.GEMINI_API_KEY || '',
    model: env.GEMINI_MODEL || 'gemini-3.8-flash',
    fallbackModel: env.GEMINI_FALLBACK_MODEL || 'gemini-3.5-flash',
    temperature: env.GEMINI_TEMPERATURE ? Number(env.GEMINI_TEMPERATURE) : undefined,
    mlMode: env.ML_MODE || 'hybrid', // hybrid | gemini_only | yolo_only | mock
    yoloProvider: env.YOLO_PROVIDER || 'roboflow', // roboflow | onnx | none
    roboflowKey: env.ROBOFLOW_API_KEY || '',
    roboflowModel: env.ROBOFLOW_MODEL || 'personal-protective-equipment-combined-model/8',
    onnxModelPath: env.ONNX_MODEL_PATH || './models/ppe-yolov8n.onnx',
    onnxClasses: (env.ONNX_CLASSES || '').split(',').map((s) => s.trim()).filter(Boolean),
  });
}
