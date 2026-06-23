# Agent Comparison Log

Track Claude Code vs Codex experiments here.
Update after completing the same (or equivalent) task with both agents.

Entries accumulate over time. Patterns across multiple entries are more reliable than any single score.

---

## Evaluation Rubric

Each dimension is rated 1–5 for each agent:

| Dimension | What it measures |
|---|---|
| **Architecture** | Respected existing patterns; no unauthorized abstractions or new dependencies |
| **Diff discipline** | Changed only what was needed; did not touch unrelated files |
| **Tests** | Wrote or updated tests; flagged when tests could not run |
| **Prompt adherence** | Followed the task description and constraints without creative interpretation |
| **Hallucinations** | Did not invent APIs, file paths, or behaviors that don't exist |
| **Overall** | Holistic score (not an average — your judgment) |

---

## Template

Copy this block for each new experiment.

```
### Feature: [Task ID and name]
Date: YYYY-MM-DD
Task type: bug fix / feature / refactor / documentation / architecture review

**Claude Code**
Architecture:     /5
Diff discipline:  /5
Tests:            /5
Prompt adherence: /5
Hallucinations:   /5
Overall:          /10
Notes:
-

**Codex**
Architecture:     /5
Diff discipline:  /5
Tests:            /5
Prompt adherence: /5
Hallucinations:   /5
Overall:          /10
Notes:
-

Winner: Claude / Codex / Tie
Lessons learned:
-
Next time:
-
```

---

## Example (do not use as data — illustrative only)

### Feature: 1.4 EPUBParser
Date: 2026-06-24
Task type: feature

**Claude Code**
Architecture:     5/5 — stayed within EPUBParser.swift, no surprises
Diff discipline:  5/5 — touched only the files scoped by the task
Tests:            2/5 — no tests written
Prompt adherence: 5/5 — implemented exactly what was asked
Hallucinations:   5/5 — no invented APIs
Overall:          9/10
Notes:
- Clean diff, easy to review
- Test gap is consistent; must be prompted explicitly

**Codex**
Architecture:     4/5 — one unnecessary helper added
Diff discipline:  3/5 — touched FileStorageService without being asked
Tests:            5/5 — full test coverage for parse paths
Prompt adherence: 4/5 — slight scope expansion
Hallucinations:   5/5 — no invented APIs
Overall:          8/10
Notes:
- Tests are a real advantage
- Scope review before accepting is mandatory

Winner: Tie (different tradeoffs)
Lessons learned:
- Explicitly ask Claude for tests on every task
- Always review Codex diff for files outside stated scope
Next time:
- Add "write tests" to the prompt template for both agents
