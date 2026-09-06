---
name: slop-clean
description: Use when the user asks Codex to remove AI-generated code slop, clean up a branch diff against main, or eliminate unnatural comments, abnormal defensive checks, any casts, and style inconsistent with the surrounding code.
---

# Slop Clean

Remove AI-generated slop introduced by the current branch while preserving the intended behavior.

## Workflow

1. Inspect the branch diff against the user-specified target, otherwise the repository's documented target or known default branch. Use local refs; do not fetch merely for cleanup. If the base cannot be established, ask rather than assuming `main`.
2. Read the surrounding code before editing so cleanup follows local style.
3. Remove only slop introduced by the branch:
   - Extra comments a human would not add, or comments inconsistent with the file.
   - Extra defensive checks or try/catch blocks that are abnormal for the area, especially in trusted or already-validated code paths.
   - Casts to `any` or equivalent type escapes used to dodge real type issues.
   - Names, branches, helpers, formatting, or structure that do not match the surrounding code.
4. Keep scope narrow. Do not turn cleanup into unrelated refactoring or behavior changes.
5. Run relevant checks for files you changed when practical.
6. Summarize the changes concisely, including material validation failures or remaining work.
