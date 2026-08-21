---
name: okf-toolkit-maintenance
description: Maintain, release, and migrate consumers of the shared OKF Toolkit. Use for generic OKF contracts, packages, CLI, visualization, adapters, hosted MCP behavior, npm Trusted Publishing, release recovery, or coordinated consumer cutovers. Do not use for curating an OKF Bundle or for consumer-specific knowledge policy.
---

# OKF Toolkit Maintenance

Work in `~/Development/okf-toolkit`. Treat its current package manifests,
workflows, scripts, and documentation as the source of truth; do not copy their
evolving implementation details into this skill.

## Establish the boundary

- Read `docs/RELEASE.md` for publication or recovery, `docs/MIGRATION.md` for a
  consumer cutover, and the affected package README before planning changes.
- Put reusable OKF v0.2 parsing, validation, analysis, visualization, storage
  adapters, CLI, signatures, and hosted MCP behavior in the toolkit. Keep
  federation, editorial authority, and domain projections in their consumers.
- Every generic operation targets exactly one selected Bundle. Do not add
  cross-Bundle discovery, search, links, graphs, or writes.
- A workflow runs from the commit captured by its tag. A workflow fix merged
  after that tag only applies to a later release; rerunning the old release
  does not pick up the fix.

## Maintain the toolkit

- Discover the public workspace packages from the repository configuration.
  Do not assume a remembered package count or dependency order.
- Keep the root and every public package on one exact release version. Preserve
  exact internal dependency versions in packed artifacts.
- Run `corepack enable`, `pnpm install --frozen-lockfile`, and `pnpm check`.
  For a proposed tag, also run
  `node scripts/verify-release.mjs --tag "<v-version>"`.
- Use the repository packaging and verification scripts when inspecting a
  release candidate. Local packing verifies artifacts; it is not a second
  publication path.
- Do not retire a consumer implementation until the current migration gate in
  `docs/MIGRATION.md` passes against one pinned candidate.

## Release through GitOps

Normal releases publish only through the repository's GitHub Actions workflow
and npm Trusted Publishing. Never add an npm token, `NODE_AUTH_TOKEN`, or
`NPM_TOKEN`, and never publish a normal toolkit release from the workstation.
Local npm authentication is reserved for the documented, explicitly approved
bootstrap of a new package name before its Trusted Publisher exists.

Follow `docs/RELEASE.md`. The release must use a signed annotated tag on the
reviewed main-line commit, a matching GitHub release, the protected
`npm-release` environment, and the CI-built artifact set. Prereleases use the
repository's prerelease tag; stable releases use its stable tag. Do not rebuild
artifacts between npm publication and GitHub asset upload.

## Recover and verify

- Anchor recovery to the tagged commit, its `RELEASE.json`, and the retained CI
  artifact. Do not substitute files from current `main`.
- npm publication is eventually consistent only after the job log shows a
  successful publish or the distribution tag shows that npm accepted the exact
  version. A temporarily missing version or attestation is then a bounded
  wait-and-retry state, not permission to republish an immutable version.
- Recover a partial release by rerunning failed jobs on the same workflow while
  its artifact remains available. Do not replace the version or tag. If the
  artifact expired after any package reached npm, stop rather than rebuild it.
- Skip an existing version only after its registry integrity and distribution
  tag match the CI artifact, then verify its GitHub provenance.
- Treat a registry integrity mismatch as a release incident and stop. Do not
  overwrite, unpublish, or repair distribution tags without a separately
  reviewed recovery decision.
- Finish only after every package in the release manifest has the exact version,
  expected distribution tag, and provenance that the repository verifier binds
  to the tagged commit and artifact digest. Every GitHub release asset digest
  must match `RELEASE.json` and `SHA256SUMS`; presence alone is insufficient.
