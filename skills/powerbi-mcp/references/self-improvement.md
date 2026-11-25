# Self-Correction and Continuous Improvement of the Skill

This file is not about Power BI -- it is about how the `powerbi-mcp` skill itself should correct itself and grow with use. Load it when: a real error happens that is not in [common-errors-prevention.md](./common-errors-prevention.md), when a workflow in `SKILL.md` proves incomplete or wrong in practice, or when the user explicitly asks to review/improve the skill.

## Principle

Every time the skill fails, gives a wrong recommendation, or the user corrects the AI on something related to Power BI/DAX/MCP, that is a sign of a gap in the reference material -- not an isolated event to forget afterwards. The skill only improves if those signals are converted into file updates.

## When to update the skill (triggers)

- **A new, real error happened** and is not documented in [common-errors-prevention.md](./common-errors-prevention.md) -> add an entry following the same format (Symptom/Root cause/How to prevent/How to fix).
- **The user corrected a recommendation** made from an existing workflow or reference -> the corresponding file is outdated or incomplete; fix the file, not just the answer in the current session.
- **A workflow in `SKILL.md` caused rework** (missing step, wrong order, a tool that no longer exists) -> fix the workflow, not just work around it on the spot.
- **`powerbi-modeling-mcp` changed behavior** (new MCP version, tool renamed/removed) -> audit `SKILL.md` and every `references/*.md` that mentions the affected tool.
- **A reference file became outdated** compared with the official Microsoft documentation (e.g. a PBIR schema change, a new best practice on Microsoft Learn/SQLBI) -> update it citing the new source.

## How to update (process)

1. **Read the whole affected file before editing** -- never edit without full context.
2. **Check whether similar content already exists in another `references/*.md`** before creating a new file -- the skill already has many files; duplicating creates contradiction. If the gap is small, it fits as a new section in an existing file, not a new file.
3. **One change at a time** -- fix one error/gap per edit, do not bundle several unrelated changes into the same update session.
4. **Add the motivation** -- every new rule in any `references/*.md` must state why it exists. A rule without the "why" becomes a blind instruction that the AI follows even when it does not apply.
5. **Check links** -- if you create a new file, add the corresponding entry to the "Table of Contents" table in `SKILL.md` (otherwise the file exists but is never loaded -- a reference file missing from the SKILL.md table of contents is never loaded).
6. **Do not experiment against the user's real model** -- test a new recommendation (e.g. a DAX pattern) against a test model or validate it with `EVALUATE` before cementing it as a rule in the reference file.

## What NOT to do

- Do not rewrite a whole file to fix a specific problem -- edit the specific section.
- Do not keep the correction only in the memory of the current conversation -- if the error can recur in another session, it belongs in a skill file, not in the conversation.
- Do not add a speculative rule ("this might cause a problem") without an observed real case -- that is the same redundancy anti-pattern described in [avoid-redundancy.md](./avoid-redundancy.md), applied to the skill itself.
- Do not duplicate content between `references/*.md` -- if two files should say the same thing, one should link to the other, not repeat it.

## Periodic audit (when the user asks to "review the skill")

1. List all `references/*.md` and confirm each one is referenced in some workflow or in the topics table of `SKILL.md` -- an orphan reference is a sign that it was forgotten or is redundant.
2. Check whether any file mentions a `powerbi-modeling-mcp` tool that no longer exists (compare against the list of MCP tools available in the current session).
3. Ask the user whether any recent error or correction from the session deserves a new entry in [common-errors-prevention.md](./common-errors-prevention.md).
4. Confirm that the description/triggers in the `SKILL.md` frontmatter still reflect the real scope (e.g. when the report visuals scope was added, the "Does NOT author report visuals" line had to be removed -- this kind of mismatch between frontmatter and actual content is the easiest to miss).
