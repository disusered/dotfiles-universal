---
name: financial-planning
description: Operate Carlos' private local-first hledger financial ledger. Use when Carlos asks to record or revise a confirmed actual, retain a source-labelled quote, inspect funding envelopes, review staged YNAB evidence, or compare a purchase against the ledger.
---

# Financial Planning

Treat hledger journals as the accounting and calculation authority. Use the
current harness only for conversation, source capture, and explicit journal
edits. Do not calculate affordability from prose or recreate ledger arithmetic.

## Run the planner

Run every command with this working directory:

`/home/carlos/Development/ME/herding-cats/workshop/skunkworks/financial-ledger`

Use only the verified CLI contract:

```text
bun run finance -- check
bun run finance -- status
bun run finance -- quotes
bun run finance -- actual
bun run finance -- ui
bun run finance -- hledger <hledger command and arguments>
bun run finance -- ynab pull [--since YYYY-MM-DD]
bun run finance -- ynab review
```

Read hledger output directly. Preserve exact dates, source IDs, currencies,
quotes, and raw YNAB evidence exactly. Let hledger derive totals and valuations.

## Start a finance turn

1. Run `check` before reporting a balance, affordability conclusion, or staged
   import result.
2. Run `status`, `quotes`, `actual`, or a requested hledger report. Do not
   derive amounts in chat.
3. Stop on hledger validation, YNAB authentication, API, or malformed-data
   failures. Report the verified failure; do not replace evidence with an
   assumption.
4. Do not access YNAB during unrelated work.

## Capture and revision

- Treat “I need/want X” as a possible quote or envelope, not permission to
  spend or fund it.
- Add an actual only when Carlos explicitly confirms it. Keep the payment date
  exact; if it is unknown, record a migration/opening entry rather than invent
  one.
- Append a new quote for a correction. Never overwrite an older quote,
  observation, or confirmed actual.
- Preserve individual quote components, currencies, sources, and uncertainty.
  Never collapse a fixture, installation, shipping, tax, or agency fee into an
  invented total.
- Never introduce financing, a funding allocation, or a purchase decision.

## Funding and FX

1. Add or move a virtual planning-envelope allocation only after Carlos
   explicitly decides it.
2. Run `status` or an hledger balance report to determine remaining capacity.
   Do not announce a total derived outside hledger.
3. Keep USD quotes in USD. Add a dated market-reference price directive only
   when Carlos chooses the source/rate policy; actual checkout or card rates
   override the reference rate.

## YNAB and preservation

- `ynab pull` is GET-only. It writes a raw private snapshot plus a generated
  pending journal; it never writes to YNAB.
- Review staged entries before reconciliation. Never automatically promote,
  deduplicate, or alter transactions, including a possible match to a manual
  actual.
- Keep the legacy SQLite planner archived and untouched. Its old price watches
  are archive evidence, not active automation.
- Keep transaction reconciliation separate from the email-to-YNAB project.
- Do not invoke the retired planner CLI, planner sync, Pi, Brain, or Brain Web.
