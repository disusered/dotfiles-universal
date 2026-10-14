# OptChat recipe reference

Author: Victor Taelin.

Source: https://gist.github.com/VictorTaelin/91837951a5ce5b38f341ec1ba1df6449

The implementation was compared with the recipe fetched on 2026-10-04. The reference content SHA-256 was `8f6997e8944d85e4df53b5704bf7c4e393e4da361071181e9cc2f7d9d1b6e430`.

The source remains upstream rather than duplicating the full article here. Its four prompt strings are preserved in `src/prompts.ts`, with attribution in `THIRD_PARTY_NOTICES.md`.

## Implementation mapping

- `src/memory.ts`: append-only log, binary summary tree, compression scheduling, bounded view, zoom/date.
- `src/compactor.ts`: contextual compression and size retries.
- `src/cache.ts`: stable Anthropic cache boundaries.
- `src/transcript.ts`: fresh context per parent run, current-run tool loop retained.
- `src/agents.ts`: asynchronous Pi SDK children and automatic completion reports.
- `src/import/`: profile-scoped historical imports, an addition to the recipe.

## Cache-view repair

The corrected recipe was fetched again for the cache-view repair, with SHA-256
`12f300f760af82bc07bc5201051d1267824ded09c9def8186e4f8144368038d8`.
The repair implements three changes in `src/memory.ts`:

- Rank eligible pairs by age from their last message, divided by their line size;
  prefer the oldest pair on equal scores.
- Above 128,000 summary bytes, keep merging toward 64,000 bytes. Retain unfinished
  batch state when parent summaries are not yet available.
- Atomically save the view partition and batch state in a versioned `view.json`
  checkpoint. Restore it on restart; recover a newer log suffix without rebuilding
  its saved prefix. Missing or invalid checkpoints warn and migrate once from the
  authoritative log and tree, without modifying their records.

Offline regression tests cover the recipe's T=10 ordering counterexample, ties,
128→64 KB batching, prefix stability below the threshold, exact restart rendering,
unfinished batches, crash ordering, and legacy/damaged-checkpoint recovery.
These tests do not establish provider cache-hit rates. Shared compactor prompts/tools,
its separate 16–32 KB view, and provider cache-breakpoint changes remain out of scope.

Profiles, native Pi UI, conversation import, and local Git checkpoints are integration choices described in the README.
