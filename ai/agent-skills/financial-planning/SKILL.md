---
name: financial-planning
description: Operate Carlos' private local-first financial ledger, purchase catalog, and explicit funding envelopes. Use when Carlos asks to record or revise a confirmed actual, retain a source-labelled quote, create or fund a purchase envelope piecemeal, inspect funding gaps, review YNAB spending evidence, or compare a purchase target with its funded balance.
---

# Financial Planning

Treat Carlos' explicit decisions as the planning authority. Use hledger as the
numeric record and calculation engine, the planner database as the purchase and
research workboard, and YNAB only as read-only spending evidence. Never turn a
historical spending statistic into money available for a purchase.

## Run the ledger

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

## Run the purchase workboard

Treat the live financial-planner SQLite database as a purchase and research
workboard, never as the source of envelope balances. Run these commands with:

`/home/carlos/Development/ME/herding-cats/workshop/skunkworks/financial-planner`

Use only this bounded CLI:

```text
bun run planner -- portfolio
bun run planner -- capture '<expense JSON>'
bun run planner -- update <expense-id> '<update JSON>'
bun run planner -- dashboard [--port PORT]
```

Amounts are integer milliunits. The projection schema has no currency field, so
do not put USD amounts into it or invent an FX conversion.

Use the local dashboard to review payment state, fulfillment, envelope balances,
funding gaps, and read-only YNAB spending signals. It may record hledger
envelope contributions only after Carlos explicitly confirms the displayed
split. Never submit the suggested split as if it were approval.

## Start a finance turn

1. Run `check` before reporting a balance, affordability conclusion, or staged
   import result.
2. Run `status`, `quotes`, `actual`, or a requested hledger report. Do not
   derive amounts in chat.
3. If the change affects a purchase, quote, envelope, or actual, run planner
   `portfolio` to resolve the exact purchase.
4. Stop on hledger validation, planner validation, YNAB authentication, API, or malformed-data
   failures. Report the verified failure; do not replace evidence with an
   assumption.
5. Do not access YNAB during unrelated work.

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
- Never introduce financing, an envelope contribution, or a purchase decision.

## Purchase envelopes

Use this model:

1. `Planning:Available` is confirmed planning money that has not been
   earmarked. It is not a monthly forecast and must not be auto-allocated.
2. Create `Planning:Envelope:<Purchase>:Funded` only when Carlos explicitly
   starts funding that purchase. A purchase may remain captured without an
   envelope.
3. Record each contribution as an exact, dated transfer from
   `Planning:Available` to the purchase's `Funded` account. Preserve its source
   and note; multiple piecemeal contributions are expected.
4. Keep `Planning:Envelope:<Purchase>:Spent` separate. When a funded purchase is
   confirmed, move the consumed amount from `Funded` to `Spent`; when it was
   never prefunded, deduct it directly from `Planning:Available` into `Spent`.
5. Never move money into, out of, or between envelopes without Carlos'
   explicit allocation decision.
6. Derive the funding target from the current source-backed quote components.
   Derive the funded balance from hledger. Use hledger or an exact command-line
   calculator for the funding gap; never use conversational arithmetic.
7. Preserve currencies separately. Do not report a combined target or gap
   across MXN and USD without an explicit FX policy.
8. Derive payment state from confirmed `Spent` postings: unpaid, partly paid,
   or paid. Keep it separate from envelope funding.
9. Mark a purchase `funded` only when its unspent envelope covers the unpaid
   remainder. Mark it `paid_pending` when the known target is paid but delivery,
   processing, appointment, or service completion is pending. Mark it
   `purchased` only when the good or service is complete.
10. Report envelope planning as: purchase, target, paid, funded, remaining gap,
    and fulfillment state. Report `Planning:Available` separately as unassigned
    money.

## Funding projections

- A funding projection is optional and uses only explicit future contribution
  amounts and dates chosen by Carlos.
- Without an explicit contribution schedule, report the current funding gap and
  no completion date.
- Do not use planner capacity bands, automatic scenario allocation, YNAB Ready
  to Assign, income, category balances, or historical surplus percentiles.
- A target month expresses preference or deadline; it does not create money.

## Refresh the planning view

After recording or revising a quote, confirmed payment, envelope contribution,
or purchase status:

1. Run ledger `check`.
2. Refresh planner `portfolio` and the dashboard snapshot.
3. Recalculate target, paid, funded, gap, and `Planning:Available` from the
   records; do not carry forward a number from chat.
4. Report what changed and whether the purchase is unpaid, partly paid,
   paid-pending, or complete.
5. If Carlos supplied an explicit future contribution schedule, refresh its
   projected dates. Otherwise report no completion date.

## Quotes, actuals, and YNAB

- `ynab pull` is GET-only. It writes a raw private snapshot plus a generated
  pending journal; it never writes to YNAB.
- Use YNAB to inspect merchants, categories, recurring charges, and spending
  trends when Carlos asks where money went or where he may be overspending.
- Never use YNAB data to create or fund a purchase envelope, infer an envelope
  contribution, calculate future purchase funding, or authorize spending.
- Review staged entries before reconciliation. Never automatically promote,
  deduplicate, or alter transactions, including a possible match to a manual
  actual.
- Apply quote corrections component by component. Preserve source and
  uncertainty in notes.
- For a paid but unfinished purchase, record exact components and mark the
  matching planner purchase `paid_pending`. Move it to `purchased` only after
  completion. Keep confirmed actuals separate from virtual planning entries so
  money is not double counted.
- Keep the SQLite copy under `financial-ledger/archive/` untouched. Mutate the
  live financial-planner database only through the bounded purchase CLI or
  local dashboard above.
- Keep transaction reconciliation separate from the email-to-YNAB project.
- Do not invoke planner capacity, forecast, scenario selection, YNAB sync,
  price-watch automation, Pi, Brain, or Brain Web.
