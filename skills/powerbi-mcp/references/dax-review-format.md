# DAX Review Output Format

Use this format when presenting DAX changes to the user as part of [Workflow: Optimize DAX Performance](../SKILL.md#workflow-optimize-dax-performance) or [Workflow: Modify an Existing Model](../SKILL.md#workflow-modify-an-existing-model). It complements the diagnostic steps in [dax-perf-decision-guide.md](./dax-perf-decision-guide.md) and the pattern catalog in [dax-perf-patterns.md](./dax-perf-patterns.md) — those tell you *what* to fix; this tells you how to *present* the fix.

## Review checklist (apply before presenting any DAX change)

- **Variables** - expensive or repeated sub-expressions stored in `VAR`
- **Function choice** - `DIVIDE` instead of `/`, `COUNTROWS` instead of `COUNT`, `SELECTEDVALUE` instead of `VALUES` where applicable
- **Context transitions** - minimized inside iterators (`SUMX`, `FILTER`, etc.)
- **BLANK handling** - preserved deliberately, not converted to 0 unless the business rule requires it
- **Naming** - variable and measure names describe the business concept, not the mechanics

## Presentation format

```dax
-- BEFORE
<original formula>

-- AFTER
<optimized formula>
```

Then, in prose (not another code block):

1. **What changed** - one line per change, mapped to the checklist above
2. **Expected impact** - performance, readability, or both; quantify only if a trace (per [dax-perf-decision-guide.md](./dax-perf-decision-guide.md)) actually measured it — otherwise say "expected" and don't invent numbers
3. **Trade-offs** - anything the user should know before accepting (e.g. a variable that duplicates logic already in another measure)

Wait for user approval before applying via [Workflow: Modify an Existing Model](../SKILL.md#workflow-modify-an-existing-model) — do not write the change until confirmed.
