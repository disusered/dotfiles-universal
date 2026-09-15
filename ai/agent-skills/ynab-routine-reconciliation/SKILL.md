---
name: ynab-routine-reconciliation
description: Reconcile a bank statement export with Carlos's live YNAB account, import missing transactions through YNAB's native import semantics, trigger linked-account refresh, and hand unapproved transactions to Carlos for QA. Use for routine YNAB runs, missing bank transactions, or account-balance reconciliation. Do not use for purchase planning or envelope funding.
---

# YNAB Routine Reconciliation

Work in `workshop/skunkworks/email-ynab-updater` and use the existing statement parser, audit artifacts, account/payee discovery, and YNAB API client. Do not create a competing capture path.

## Required outcome

Bring the live account to the source-backed bank balance, leave imported transactions unapproved for Carlos's QA, and hand off immediately after the import milestone.

## Routine

1. Read the supplied statement/export and the stated current balance.
2. Trigger the actual linked-account refresh with `POST /v1/plans/{plan_id}/transactions/import`. This is the API equivalent of clicking Import. An empty `transaction_ids` array is a successful refresh with nothing new.
3. Run one statement audit against the refreshed live account. Treat the bank balance as a check, never as evidence for an invented adjustment.
4. Reconcile each source row against the account's uncleared transactions before creating anything. When a pending row already represents the same charge, update that row in place to the posted date, amount, and cleared state. One bank charge keeps one row.
5. Import the remaining source-backed missing rows with `POST /v1/plans/{plan_id}/transactions`.
6. Read the account balance once after the write and hand the milestone to Carlos for QA. Do not begin another audit loop unless QA identifies a defect.

## Transaction import contract

- Use YNAB's standard import ID: `YNAB:<milliunit_amount>:<iso_date>:<occurrence>`.
- Derive `occurrence` deterministically for rows sharing an account, date, and amount. Never use a custom prefix, omit `import_id`, or force a distinct user-entered transaction to bypass matching.
- When several same-amount rows fall within YNAB's ±10-day matching window, submit the complete collision component together so YNAB can match existing user-entered rows and create only the missing occurrences.
- A settled source row that matches an existing uncleared transaction is an update, not an import. Send `PATCH /v1/plans/{plan_id}/transactions/{transaction_id}` with the source date, amount, and `cleared: "cleared"`. A pending row is authorized to become the settled row the moment the statement shows the charge posted; never delete the pending row and re-create it as a second transaction.
- Set `approved: false` or omit `approved`. Carlos approves imports in YNAB.
- Use `cleared: "cleared"` for posted bank rows and `cleared: "uncleared"` for pending bank rows.
- Set `memo: null` or omit it. Never synthesize audit text, references, provenance, or explanations into the user's memo field.
- Reuse established payees. Every created or updated row carries a payee and a category, taken from the account's established payee/category conventions for that merchant. Do not leave `Uncategorized` or a missing payee on an imported row, and do not invent a category when the evidence is ambiguous.

## API response handling

Bulk create responses contain `transaction_ids` and `duplicate_import_ids`. `transaction_ids.length` is not required to equal the submitted row count because YNAB may match imported rows to existing user-entered transactions. Do not treat a count mismatch as failure when the HTTP response succeeded.

Use `duplicate_import_ids` to identify suppressed imports. Never retry with a missing or custom import ID. Correct the occurrence/component and resubmit through native import semantics.

## QA handoff

Report only:

- refresh result;
- imported/matched/duplicate counts;
- resulting account balance;
- the number of unapproved transactions awaiting Carlos's QA.

Stop at that milestone. Apply QA feedback directly; do not self-approve transactions, add explanatory memos, or launch unsolicited verification passes.
