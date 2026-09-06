# Opus with a Fable advisor

Claude Code keeps `opus[1m]` as the primary and `fable` as the advisor. Keep the
current effort settings until actual task results justify changing them.

Consult the advisor for a consequential design choice with unresolved tradeoffs,
or a recurring failure after focused diagnosis. State the decision, observations,
attempts, and constraints in the consultation. Use ordinary subagents for sizeable
independent execution or research; keep short tasks local.

Do not consult routinely for small edits or as an automatic completion review.
Reconcile advisor guidance with code and observed results; it does not grant
permissions or expand the user's request. If unavailable or declined, continue
work that does not depend on it and report a material unresolved decision.

The advisor receives the full conversation on each call, without advisor caching.
Availability and billing depend on the account and plan. A saved setting alone
does not establish that the advisor ran or that its usage is included. Preserve
existing billing consent; do not accept a credit-billing prompt as setup cleanup.

`/advisor` inspects or changes the selection; `/advisor off` clears it. There is
no deterministic per-task advisor-call cap. Use the session's visible advisor
result and `/usage` when checking actual use.

Sources checked 2026-09-05: [advisor](https://code.claude.com/docs/en/advisor),
[Opus 5 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5).
