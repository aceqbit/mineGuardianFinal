// Function declarations offered to Gemini (functionDeclarations with parametersJsonSchema).
const imageRef = { type: 'object', properties: { image_ref: { type: 'string', description: 'Always "current". Any other value is ignored.' } } };

export const FUNCTION_DECLARATIONS = [
  {
    name: 'detect_ppe_yolo',
    description: 'Runs the YOLO PPE detector on the current photo. Returns detections (label, ppeKey, polarity + for worn / - for a "NO-..." class, confidence, normalised box), person count, the main person box and whether a fall was detected. YOLO is a second opinion: it has false positives and misses.',
    parametersJsonSchema: imageRef,
  },
  {
    name: 'analyze_image_quality',
    description: 'Classical image-quality check on the current photo: width, height, blur score, brightness, contrast, clipped-pixel fraction and an ok / poor verdict with reasons.',
    parametersJsonSchema: imageRef,
  },
  {
    name: 'get_required_ppe',
    description: 'Returns which PPE keys are required (and not required) in the worker\'s zone.',
    parametersJsonSchema: { type: 'object', properties: { zone_id: { type: 'string', description: 'Zone id or zone code such as Z-B' } }, required: ['zone_id'] },
  },
  {
    name: 'verify_photo_integrity',
    description: 'Returns the server-side integrity facts for a shift photo: source, capture and receive times, age at upload, clock skew, integrity flags, GPS accuracy, inside-zone and within-shift.',
    parametersJsonSchema: { type: 'object', properties: { checkin_id: { type: 'string' } }, required: ['checkin_id'] },
  },
  {
    name: 'get_worker_history',
    description: 'Last 30 days for a worker: check-ins, decided compliant / non-compliant, most-missed items and current streak. Use only to word risks; it never changes what is visible.',
    parametersJsonSchema: { type: 'object', properties: { worker_id: { type: 'string' } }, required: ['worker_id'] },
  },
  {
    name: 'get_hazard_protocol',
    description: 'Immediate actions, things not to do and who to notify for a hazard category.',
    parametersJsonSchema: { type: 'object', properties: { category: { type: 'string', enum: ['GAS_LEAK', 'ROOF_FALL', 'FIRE_SMOKE', 'FLOODING', 'ELECTRICAL', 'EQUIPMENT_FAILURE', 'VENTILATION_FAILURE', 'OTHER'] } }, required: ['category'] },
  },
];
