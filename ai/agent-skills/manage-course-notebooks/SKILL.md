---
name: manage-course-notebooks
description: Create, audit, repair, and maintain course Jupyter notebook workspaces backed by uv, one course-level ipykernel, Jupytext, Quarto, and Molten. Use when setting up a coding course or lesson workbook, creating an .ipynb file, registering or diagnosing a Jupyter kernelspec, fixing a notebook/environment mismatch, launching the isolated notebook Neovim profile, or checking stale user kernels.
---

# Manage Course Notebooks

Keep course content, Python dependencies, kernels, editor integration, and
secrets as separate concerns.

## Establish the boundary

1. Read applicable repository instructions.
2. Treat one course directory as one `uv` project unless incompatible Python
   or dependency requirements prove that it needs another environment.
3. Register one kernelspec per course environment, not per lesson.
4. Default to one notebook per coding lesson while allowing a course to group
   or split notebooks when that is clearer.
5. Inspect lesson imports or dependency metadata before adding a library. Ask
   before adding a library that is neither present nor explicitly approved.

Each notebook starts its own kernel process when opened independently even when
multiple notebooks select the same kernelspec. Their in-memory state does not
become shared merely because the kernelspec is shared.

## Create or repair the course environment

From the course directory:

```sh
uv init --bare --python 3.11 --vcs none .
uv add ipykernel
uv sync
```

Skip initialization when `pyproject.toml` already exists. Add only verified
lesson dependencies. Preserve an existing Python version and lockfile unless
the course requires a change.

Register a stable course-level kernel name:

```sh
uv run python -m ipykernel install --user \
  --name <course-slug> \
  --display-name "<human-readable course name>"
```

Use a lowercase hyphenated kernel name. Re-register the same name when its
interpreter path is stale; do not create a suffixed duplicate.

## Create a lesson notebook

Use the bundled generator to produce valid notebook v4 JSON:

```sh
python scripts/create_notebook.py \
  --course-dir <course-dir> \
  --output notebooks/<lesson-slug>.ipynb \
  --title "<lesson title>" \
  --course-url "<course URL>" \
  --lesson-url "<lesson URL>" \
  --kernel-name <course-slug> \
  --kernel-display-name "<human-readable course name>"
```

The generator refuses to overwrite a notebook. Preserve gated course code as a
blank, labelled transcription cell unless the user supplied the actual code.

## Audit the result

Run:

```sh
python scripts/audit_course.py \
  --course-dir <course-dir> \
  --kernel-name <course-slug>
```

Fix every reported mismatch. The audit checks notebook JSON and metadata, the
course interpreter, and the registered kernelspec interpreter.

Also verify course imports with the course interpreter. Do not make a paid or
credential-dependent API request merely to prove local notebook execution.

## Work in Neovim

Open the notebook with:

```sh
nvim-notebook notebooks/<lesson-slug>.ipynb
```

The isolated profile should initialize the kernel named in notebook metadata.
Use `<leader>ji` for manual initialization, `<leader>jc` for the current cell,
`<leader>jl` for the current line, and `<leader>ja` for all cells. Import saved
outputs with `<leader>jI` and export Molten outputs with `<leader>jE`.

Keep output import and export explicit. Jupytext round trips plaintext and
notebook source; Molten owns the live execution outputs.

## Handle secrets

Never put a literal API key in a notebook, committed dotenv file, or shell
history. Prefer a committed template containing a 1Password secret reference:

```dotenv
ANTHROPIC_API_KEY=op://<vault>/<item>/<field>
```

Inject it only for the editor process:

```sh
op run --env-file=.env.tpl -- nvim-notebook notebooks/<lesson>.ipynb
```

If the referenced item does not exist, document the gap and leave live API
verification pending.

## Triage stale kernels

List kernels with `jupyter kernelspec list --json` and inspect each
`kernel.json`. A kernelspec is stale only when its configured interpreter no
longer exists or the project has intentionally moved.

Removing a kernelspec is destructive user-state maintenance. Resolve the exact
name and path, obtain authorization when it was not already explicit, then use
`jupyter kernelspec remove <exact-name>`. Never remove a kernel merely because
it is unrelated to the current course.
