"""Per-million-token pricing for the eval cost estimator.

Update these whenever provider pricing changes. Numbers are USD per 1M tokens.
The numbers below are approximate placeholders rounded from public pricing
pages at time of writing. Verify against the provider's current pricing page
before relying on these for unit-economics decisions.

Lookup is by exact model string match. Unknown models return zeros and the
estimator logs a warning.
"""
from __future__ import annotations

# (input_per_mtok_usd, output_per_mtok_usd)
PRICING: dict[str, tuple[float, float]] = {
    # Anthropic — verify at https://www.anthropic.com/pricing
    "claude-opus-4-7": (15.00, 75.00),
    "claude-opus-4-6": (15.00, 75.00),
    "claude-opus-4-5-20251101": (15.00, 75.00),
    "claude-sonnet-4-6": (3.00, 15.00),
    "claude-sonnet-4-5-20250929": (3.00, 15.00),
    "claude-haiku-4-5-20251001": (1.00, 5.00),

    # Google — verify at https://ai.google.dev/pricing
    "gemini-2.5-pro": (1.25, 10.00),
    "gemini-2.5-pro-preview-05-06": (1.25, 10.00),

    # OpenAI — verify at https://openai.com/api/pricing
    "gpt-5.4": (5.00, 15.00),
    "gpt-4o": (2.50, 10.00),
}


def estimate_cost_cents(model: str, input_tokens: int, output_tokens: int) -> int:
    """Return estimated cost in integer cents for a single call."""
    if model not in PRICING:
        return 0
    in_rate, out_rate = PRICING[model]
    dollars = (input_tokens / 1_000_000) * in_rate + (output_tokens / 1_000_000) * out_rate
    return round(dollars * 100)


def lookup(model: str) -> tuple[float, float] | None:
    return PRICING.get(model)
