---
name: ynab-routine-reconciliation
description: Reconcile a bank statement export with Carlos's live YNAB account, import missing transactions through YNAB's native import semantics, trigger linked-account refresh, and hand unapproved transactions to Carlos for QA. Use for routine YNAB runs, missing bank transactions, or account-balance reconciliation. Do not use for purchase planning or envelope funding.
---

# YNAB Routine Reconciliation

Work in `workshop/skunkworks/email-ynab-updater` on the Herding Cats `main`
checkout, from that project directory. The run is four commands and the code owns
the reconciliation rules. Writing a script to do this job is the failure mode this
skill exists to prevent. The private payee map and discovery file live in that
checkout's gitignored `fixtures/private/ynab/`; a linked worktree has its own empty
copy, so do not run from one.

## Routine

```bash
bash scripts/bootstrap-ynab-env.sh                    # 0. token once, not per command

bun run ynab:pull -- --budget-id <id> --account-id <id> --refresh \
  --out fixtures/private/ynab/state-<account>-<date>.json   # 1. the only live read

bun run ynab:plan-statement -- --bank <bank> --input <statement> \
  --coverage-start <date> --coverage-end <date> \
  --snapshot fixtures/private/ynab/state-<account>-<date>.json \
  --out fixtures/private/ynab/<bank>-<date>-plan.json        # 2. offline

bun run ynab:apply-evidence -- --plan <plan>                 # 3. dry run
bun run ynab:apply-evidence -- --plan <plan> --confirm-source-backed-writes
```

Budget and account ids come from `fixtures/private/ynab/discovery.json`; run
`bun run ynab:discover` if it is stale. Banorte exports do not declare their coverage, so
pass it. BanBajío PDFs declare their own period. An empty `transaction_ids` array from the
refresh is success with nothing new.

## Read the plan before applying

- `balanceDeltaMilliunits` must be `0`. A non-zero delta means the plan does not account
  for every statement row: report the delta and stop. Never invent a balance adjustment.
- `blockers` lists rows with no confident payee. Resolve them from the account's existing
  conventions or hand them to Carlos. Do not guess a merchant.
- Inspect created rows' payees against their statement merchants. An amount-only
  ledger match can assign a different merchant's payee; stop if the plan shows one.
- The dry run prints operation counts and the projected balance. Check them, then apply.

## Never

- No `curl`, `node -e`, `bun -e`, heredocs, or new files under `fixtures/`. If these
  commands cannot express the job, say so and stop.
- No direct `op` calls; step 0 handles credentials.
- No live YNAB reads during planning, and no second audit pass after applying.
- Never send `approved` on an existing row, never edit a settled or reconciled row, and
  never write into the memo field.

## The code owns these rules

Check them in the plan; do not reimplement them. Import ids are
`YNAB:<milliunits>:<iso_date>:<occurrence>`. Pending bank rows enter uncleared, posted
rows cleared. A pending row that already exists in YNAB is updated in place, never
deleted and recreated, including when a hold, tip or currency conversion changed its
amount at posting; that change counts in the projected balance. A payee comes from
the account's conventions (canonical map, YNAB's stored import names, merchant-agreeing
ledger history); a card merchant never seen before is proposed under the bank's name
for Carlos's review. A SPEI to Carlos's own name at BanBajío is `Transfer : BanBajio`.
A row YNAB's own importer would absorb is left out of the plan. Created rows carry a
payee, a category when the ledger has one for that payee, and stay unapproved. A create count below the
number of rows submitted is YNAB matching an import to a hand-entered row, not a failure;
`duplicate_import_ids` names the suppressed ones. YNAB refuses a new date on a split
transaction, so the plan reports one as a blocker instead of attempting it.

## If a run changed something it should not have

```bash
bun run ynab:restore-rows -- --snapshot <pre-run state> --fields approved,date,cleared
bun run ynab:restore-rows -- --snapshot <pre-run state> --confirm-restore
```

Show Carlos the dry run first. Rows the run created are absent from the snapshot and are
never touched. Do not hand-write a repair script.

## QA handoff

Report only the refresh result; created, matched and duplicate counts; the resulting
account balance; and how many transactions are waiting for Carlos's approval. Stop at
that milestone. Apply QA feedback directly; do not self-approve, add memos, or launch
unsolicited verification passes.
