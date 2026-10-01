import test from 'node:test';
import assert from 'node:assert/strict';
import { mapLabel, detectableKeysFor, summarizeDetections, ROBOFLOW_CLASSES } from '../src/modules/ai-analyzer/tools/yolo.map.js';
import { parseRoboflow } from '../src/modules/ai-analyzer/tools/yolo.roboflow.js';
import { decodeYoloOutput, letterboxInfo } from '../src/modules/ai-analyzer/tools/yolo.onnx.js';

test('label mapping is case, space and hyphen insensitive; NO- classes are negative', () => {
  assert.deepEqual(mapLabel('Hardhat'), { kind: 'ppe', ppeKey: 'HELMET', polarity: '+' });
  assert.deepEqual(mapLabel('NO-Hardhat'), { kind: 'ppe', ppeKey: 'HELMET', polarity: '-' });
  assert.deepEqual(mapLabel('no hard hat'.replace('hard hat', 'hardhat')), { kind: 'ppe', ppeKey: 'HELMET', polarity: '-' });
  assert.equal(mapLabel('Safety Vest').ppeKey, 'REFLECTIVE_VEST');
  assert.equal(mapLabel('NO-Safety Vest').polarity, '-');
  assert.equal(mapLabel('Goggles').ppeKey, 'EYE_PROTECTION');
  assert.equal(mapLabel('Mask').ppeKey, 'DUST_MASK');
  assert.equal(mapLabel('Safety Shoe').ppeKey, 'SAFETY_BOOTS');
  assert.equal(mapLabel('Person').kind, 'person');
  assert.equal(mapLabel('Fall-Detected').kind, 'fall');
  assert.equal(mapLabel('Ladder').kind, 'ignore');
  assert.equal(mapLabel('Weird thing').kind, 'unknown');
});

test('Roboflow response: centre -> top-left normalisation, labels, main person, fall', () => {
  const json = {
    image: { width: 1000, height: 500 },
    predictions: [
      { x: 500, y: 250, width: 400, height: 480, confidence: 0.95, class: 'Person' },
      { x: 500, y: 60, width: 100, height: 80, confidence: 0.88, class: 'Hardhat' },
      { x: 120, y: 250, width: 100, height: 300, confidence: 0.9, class: 'Person' },
      { x: 500, y: 300, width: 200, height: 200, confidence: 0.74, class: 'NO-Safety Vest' },
      { x: 300, y: 400, width: 50, height: 50, confidence: 0.8, class: 'Fall-Detected' },
      { x: 900, y: 100, width: 40, height: 40, confidence: 0.6, class: 'Ladder' },
    ],
  };
  const raw = parseRoboflow(json);
  assert.deepEqual(raw[1].box, { x: 0.45, y: 0.04, w: 0.1, h: 0.16 });
  const s = summarizeDetections(raw, { provider: 'roboflow', detectableKeys: detectableKeysFor(ROBOFLOW_CLASSES), latencyMs: 5 });
  assert.equal(s.personCount, 2);
  assert.deepEqual(s.mainPersonBox, { x: 0.3, y: 0.02, w: 0.4, h: 0.96 }); // the larger person
  assert.equal(s.fallDetected.value, true);
  assert.equal(s.fallDetected.confidence, 0.8);
  assert.equal(s.detections.length, 2); // hardhat + no safety vest; ladder ignored, person/fall removed from the list
  assert.deepEqual(s.detections.map((d) => `${d.ppeKey}${d.polarity}`).sort(), ['HELMET+', 'REFLECTIVE_VEST-']);
  assert.ok(s.detectableKeys.includes('GLOVES'));
  assert.ok(!s.detectableKeys.includes('SAFETY_BOOTS'));
});

test('ONNX decoding on a tiny synthetic tensor: threshold, undo letterbox, per-class NMS', () => {
  const nc = 2, n = 4;
  const orig = { width: 1280, height: 640 };
  const lb = letterboxInfo(orig.width, orig.height); // scale 0.5, padY 160
  assert.equal(lb.scale, 0.5);
  assert.equal(lb.padY, 160);
  // columns: [cx, cy, w, h, score0, score1]; layout [4+nc][n]
  const cols = [
    [320, 320, 100, 200, 0.9, 0.0], // class 0, strong
    [322, 322, 100, 200, 0.8, 0.0], // class 0, overlaps the first -> suppressed
    [100, 300, 50, 50, 0.1, 0.1], // below threshold
    [500, 400, 80, 80, 0.0, 0.7], // class 1
  ];
  const data = new Float32Array((4 + nc) * n);
  cols.forEach((c, i) => c.forEach((v, r) => { data[r * n + i] = v; }));
  const out = decodeYoloOutput(data, nc, { n, orig, lb, classes: ['Helmet', 'Vest'] });
  assert.equal(out.length, 2);
  assert.equal(out[0].label, 'Helmet');
  // first box: cx=320 -> x = (320-50-0)/0.5 = 540 -> /1280 ; cy=320 -> y=(320-100-160)/0.5 = 120 -> /640
  assert.ok(Math.abs(out[0].box.x - 540 / 1280) < 1e-6);
  assert.ok(Math.abs(out[0].box.y - 120 / 640) < 1e-6);
  assert.ok(Math.abs(out[0].box.w - 200 / 1280) < 1e-6);
  assert.equal(out[1].label, 'Vest');
});
