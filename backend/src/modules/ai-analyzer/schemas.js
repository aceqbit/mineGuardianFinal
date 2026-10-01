// Response schemas: JSON Schema for Gemini (only type/properties/required/enum/items/minimum/maximum; no oneOf/$ref) + matching zod.
import { z } from 'zod';
import { PPE_KEY, PPE_STATUS, EMERGENCY_TYPE, HAZARD_CATEGORY, HAZARD_SEVERITY } from '../../contracts/enums.js';

const num01 = { type: 'number', minimum: 0, maximum: 1 };
const conf = { type: 'number', minimum: 0, maximum: 0.99 };
const str = { type: 'string' };
const strArr = { type: 'array', items: str };

const emergencyJson = {
  type: 'object',
  properties: { detected: { type: 'boolean' }, possible: { type: 'boolean' }, type: { type: 'string', enum: [...EMERGENCY_TYPE] }, confidence: conf, evidence: str },
  required: ['detected', 'possible', 'type', 'confidence', 'evidence'],
};

const reportJson = {
  type: 'object',
  properties: { observations: strArr, risks: strArr, recommended_actions: strArr },
  required: ['observations', 'risks', 'recommended_actions'],
};

export const ppeResponseSchema = {
  type: 'object',
  properties: {
    mode: { type: 'string', enum: ['PPE_COMPLIANCE'] },
    image_relevance: { type: 'string', enum: ['RELEVANT', 'IRRELEVANT'] },
    framing: {
      type: 'object',
      properties: { full_body_visible: { type: 'boolean' }, persons_count: { type: 'integer', minimum: 0, maximum: 50 }, notes: str },
      required: ['full_body_visible', 'persons_count', 'notes'],
    },
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          key: { type: 'string', enum: [...PPE_KEY] },
          status: { type: 'string', enum: PPE_STATUS.filter((s) => s !== 'NOT_REQUIRED') },
          confidence: conf,
          evidence: str,
          region: { type: 'object', properties: { x: num01, y: num01, w: num01, h: num01 }, required: ['x', 'y', 'w', 'h'] },
        },
        required: ['key', 'status', 'confidence', 'evidence'],
      },
    },
    emergency: emergencyJson,
    conflicts: strArr,
    limitations: strArr,
    summary: { type: 'string' },
    report: reportJson,
  },
  required: ['mode', 'image_relevance', 'framing', 'items', 'emergency', 'conflicts', 'limitations', 'summary', 'report'],
};

export const hazardResponseSchema = {
  type: 'object',
  properties: {
    mode: { type: 'string', enum: ['HAZARD_SCENE'] },
    image_relevance: { type: 'string', enum: ['RELEVANT', 'IRRELEVANT'] },
    hazard_description: str,
    category_claimed: { type: 'string', enum: [...HAZARD_CATEGORY] },
    category_observed: { type: 'string', enum: [...HAZARD_CATEGORY] },
    category_matches: { type: 'boolean' },
    severity: { type: 'string', enum: [...HAZARD_SEVERITY] },
    severity_confidence: conf,
    affected_area_estimate: str,
    emergency: emergencyJson,
    limitations: strArr,
    summary: { type: 'string' },
    report: reportJson,
  },
  required: ['mode', 'image_relevance', 'hazard_description', 'category_claimed', 'category_observed', 'category_matches', 'severity', 'severity_confidence', 'affected_area_estimate', 'emergency', 'limitations', 'summary', 'report'],
};

// ---- zod mirrors ----
const zEmergency = z.object({ detected: z.boolean(), possible: z.boolean(), type: z.enum(EMERGENCY_TYPE), confidence: z.number().min(0).max(1), evidence: z.string() });
const zReport = z.object({ observations: z.array(z.string()), risks: z.array(z.string()), recommended_actions: z.array(z.string()) });
const zRegion = z.object({ x: z.number().min(0).max(1), y: z.number().min(0).max(1), w: z.number().min(0).max(1), h: z.number().min(0).max(1) });

export const ppeZod = z.object({
  mode: z.literal('PPE_COMPLIANCE'),
  image_relevance: z.enum(['RELEVANT', 'IRRELEVANT']),
  framing: z.object({ full_body_visible: z.boolean(), persons_count: z.number().int().min(0), notes: z.string() }),
  items: z.array(z.object({ key: z.enum(PPE_KEY), status: z.enum(['PRESENT', 'ABSENT', 'UNCERTAIN']), confidence: z.number().min(0).max(1), evidence: z.string(), region: zRegion.optional() })),
  emergency: zEmergency,
  conflicts: z.array(z.string()),
  limitations: z.array(z.string()),
  summary: z.string(),
  report: zReport,
});

export const hazardZod = z.object({
  mode: z.literal('HAZARD_SCENE'),
  image_relevance: z.enum(['RELEVANT', 'IRRELEVANT']),
  hazard_description: z.string(),
  category_claimed: z.enum(HAZARD_CATEGORY),
  category_observed: z.enum(HAZARD_CATEGORY),
  category_matches: z.boolean(),
  severity: z.enum(HAZARD_SEVERITY),
  severity_confidence: z.number().min(0).max(1),
  affected_area_estimate: z.string(),
  emergency: zEmergency,
  limitations: z.array(z.string()),
  summary: z.string(),
  report: zReport,
});
