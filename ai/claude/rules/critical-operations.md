# Critical Operations

## Terraform / OpenTofu

- Never run `tofu`, `terraform`, `tofu init`, `tofu plan`, or `tofu apply` locally.
- Infrastructure repositories use CI for planning and applying changes.

## Commits

- Commit messages must be 80 characters or fewer.
- Do not add footers, signatures, or tool attribution.
- Agent-created commits must use `git commit -S`.
- After committing, run `git verify-commit HEAD` and treat verification failure as a failed commit task.
