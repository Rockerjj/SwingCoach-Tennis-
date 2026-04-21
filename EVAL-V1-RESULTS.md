# Tennis Coach AI Provider Eval — eval-v1 Results

**Date:** 2026-04-20
**Sample:** 6 captured sessions (4 with strong stroke data, 2 empty/no-stroke)
**Providers:** Gemini 2.5 Pro, Claude Opus 4.7, Claude Sonnet 4.6
**Evaluation method:** Blind read of session-level + first-stroke output across 2 strongest sessions (2D930A12 — 5 strokes; 2034763D — 4 strokes), revealed key after assessment.

## Verdict: Opus 4.7

Switch `COACHING_PROVIDER=claude_opus` as the production default.

## Summary table

| Provider | Success | Avg latency | Avg cost/session | Session-level fields complete | Source discipline |
|----------|---------|-------------|------------------|-------------------------------|-------------------|
| **Opus 4.7** | 6/6 | 81 s | $0.69 | 6/6 | Empty when no source — strict |
| Sonnet 4.6 | 6/6 | 150 s | $0.18 | 6/6 | Cites 2-4 broadly per stroke |
| Gemini 2.5 Pro | 6/6 (with coercion) | 83 s | $0.08 | **3/6** — bare list on the rest | Cites 2-4 broadly per stroke |

## Why Opus wins

1. **Coaching prose specificity.** Tightest, most memorable cues ("opponent should see your back" rather than "rotate your shoulders"). Catches multiple issues per stroke.
2. **Source discipline.** Returns empty `verified_sources` when no source is directly attributable, exactly per the prompt's anti-hallucination rule. Sonnet and Gemini cite 2-4 sources per stroke even when they likely shouldn't.
3. **Reliability.** All 6 sessions returned complete `AnalysisResponse` objects with all session-level fields populated.
4. **Speed.** Tied with Gemini for fastest (~81s vs Sonnet's 150s), despite costing more per token.

## Why not Gemini, despite being 8x cheaper

**Structural reliability problem.** On 3 of 6 sessions, Gemini returned a bare JSON list of stroke entries instead of the `AnalysisResponse` object. Our coercion helper salvages the parse, but the user gets a session with **no `session_grade`, no `top_priority`, no `session_summary`, no `overall_mechanics_score`** — exactly the fields the iOS hero screen displays. That's a silent UX failure: the analysis "succeeds" but the session card is blank.

Until this can be fixed at the prompt level (or Gemini ships a more reliable structured output), it's not viable as primary.

## Why not Sonnet (yet)

Sonnet's coaching quality is very close to Opus — catches similar issues, similarly thorough, sometimes more verbose. At 4x lower cost than Opus ($0.18 vs $0.69) it's the obvious cost-optimization candidate.

But:
- Sonnet was the slowest provider (150s avg vs 81s for Opus and Gemini). User-perceived latency matters at the launch quality bar.
- Sonnet is looser on source citation discipline.
- We're pre-launch. Quality is the differentiator, not unit economics.

**Re-evaluate Sonnet as the primary once we hit ~500 sessions/day** and AI cost becomes a meaningful line item.

## Cost projections

| Provider | 100 sessions/day | 1000 sessions/day |
|----------|------------------|-------------------|
| Opus 4.7 | $69/day = $2,070/mo | $690/day = $20,700/mo |
| Sonnet 4.6 | $18/day | $180/day = $5,400/mo |
| Gemini 2.5 Pro | $8/day | $80/day = $2,400/mo |

## Recommended next steps

1. **Now:** Set `COACHING_PROVIDER=claude_opus` in production `.env`. One-line change.
2. **This week:** Add an Opus-specific prompt pass — its `verified_sources` discipline and instruction-following are strong, so we can probably tighten the prompt further without it drifting.
3. **Before scale:** Re-eval Sonnet vs Opus on 15-20 sessions to confirm Sonnet quality is close enough to switch when cost matters.
4. **Open question:** Investigate why Gemini returns bare lists. Possible causes: prompt formatting (markdown JSON template confuses it), `response_mime_type=application/json` not enforcing object structure, or Gemini interpreting `strokes_detected: [...]` as the root. If we can fix this, Gemini becomes viable as a cost-optimized fallback.

## Sample size caveat

This eval used 6 sessions, smaller than the planned 10. Results are directional rather than statistically rigorous. The Opus-vs-Gemini gap on session-level structure (50% failure rate) is large enough that more samples wouldn't change the verdict on Gemini. The Opus-vs-Sonnet quality gap is closer and would benefit from a larger sample before locking in the long-term choice.
