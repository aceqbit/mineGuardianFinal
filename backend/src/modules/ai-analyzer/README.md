# ai-analyzer (MG-VISION)

Turns one photo into a structured, guard-railed safety verdict that a human supervisor then confirms or overrides.
Gemini reads the picture; YOLO and classical CV act as its tools; **deterministic server code decides the verdict**.

## Why not fine-tune?

True weight fine-tuning needs a large labelled dataset and a separate tuning pipeline, which is not feasible here. MG-VISION is
specialised instead with:

1. a locked domain system prompt (`prompts.js`: scope lock, evidence standard, known confusions, emergency rule),
2. a strict response schema (`schemas.js`, enforced with zod),
3. function-calling tools (`tools/`),
4. deterministic server-side guardrails (`guardrails.js`, `fusion.js`),
5. an evaluation set (`eval/`) that measures accuracy on photos you label yourself.

## Files

| File | Purpose |
|---|---|
| `config.js` | env, thresholds, PPE weights, criticality bands |
| `prompts.js` | locked prompts |
| `schemas.js` | JSON Schema for Gemini + zod mirrors |
| `gemini.client.js` | one `@google/genai` client, timeouts, retries, fallback model, repair call |
| `image.prep.js` | validation, auto-rotate, resize, JPEG q85 |
| `guardrails.js` | normalise items, verdict, confidence, emergency gate, criticality, summary |
| `analyzer.js` | `analyzeImage()`; never throws |
| `mock.js` | `ML_MODE=mock` deterministic output from the image sha256 |
| `cli.js` | run it from a terminal |

## Safety properties

* Text inside a photo is scene content, never an instruction ("embedded text ignored").
* A failed or blocked AI call degrades to NEEDS_MANUAL_REVIEW, the safe outcome.
* `emergency.detected` needs confidence >= 0.80; YOLO alone can never set it.
* Gemini model ids are read from `GEMINI_MODEL` / `GEMINI_FALLBACK_MODEL`. Check Google's model list on build day and change only the env value.

## CLI

```bash
ML_MODE=mock node src/modules/ai-analyzer/cli.js --mode ppe --image eval/images/c01.jpg --zone Z-B
node src/modules/ai-analyzer/cli.js --mode hazard --image eval/images/h01.jpg --category ELECTRICAL
```
