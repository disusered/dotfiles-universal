# Agent Instructions

## STOP — Read These First

These rules are violated every session. They are NON-NEGOTIABLE:

- **NEVER run `tofu`, `terraform`, `tofu init`, `tofu plan`, or `tofu apply` locally.** The tailscale-infra repo (`~/Development/ME/tailscale`) uses GitHub Actions CI: plan on PR, apply on merge to main. Commit and push. That's it. The README says "Never run `tofu init/plan/apply` locally." There are no credentials in the environment. It will fail. And you will have wasted everyone's time.

## Git Remote Operations

Do not run `git pull`, `git pull --rebase`, or `git push` as a session-completion routine. Only run remote git operations when the user explicitly asks.

## Git Commit Signing

- **NEVER create unsigned commits.** All agent-created commits must be GPG-signed.
- Use `git commit -S ...` for every commit. Do not rely only on ambient git config.
- **NEVER use `--no-gpg-sign`, `commit.gpgsign=false`, or any other signing bypass.**
- If signing fails, stop and report the exact error. Do not retry with signing disabled.
- After every agent-created commit, run `git verify-commit HEAD`. Treat verification failure as a failed commit task until the commit is replaced with a signed, verifiable commit.

## Repository Overview

This is a universal dotfiles repository managed by [Rotz](https://github.com/volllly/rotz), a cross-platform dotfile manager. It supports **Linux (Fedora & Arch)**, **macOS**, and **Windows** environments with platform-specific configurations.

## Core Commands

### Rotz Dotfile Management

```bash
# Install dotfiles (apply symlinks and run installation commands)
~/.rotz/bin/rotz install

# Install specific dotfile module
~/.rotz/bin/rotz install /tools/neovim

# Link dotfiles without running installation commands
~/.rotz/bin/rotz link

# Check status of dotfiles
~/.rotz/bin/rotz status
```

## Architecture

### Rotz Configuration System

Rotz uses `dot.yaml` files throughout the repository to define:

- **installs**: Commands to install packages/dependencies
- **links**: Symlink mappings from repo files to system locations
- **depends**: Dependency tree (modules that must be installed first)

Platform-specific configurations use conditional syntax:

- `linux[whoami.distro^="Arch"]` - Arch Linux
- `linux[whoami.distro^="Fedora"]` - Fedora Linux
- `windows` - Windows
- `linux|darwin` - Linux or macOS
- `global` - All platforms

### Directory Structure

- **`/tools`** - Application configurations (git, neovim, zsh, kitty, hyprland, etc.)
- **`/languages`** - Programming language toolchains (ruby, node, python, rust, go, dotnet, lua)
- **`/lib`** - System libraries and dependencies (pipewire, qt, avahi, uwsm, xdg)
- **`/arch`** - Arch Linux specific apps (keychron, emote, swappy, wlogout, wttrbar)
- **`/ai`** - AI tool configurations (claude, gemini, postgres-mcp, mcp-chrome)
- **`/packages`** - Package managers (scoop, homebrew, rancher)
- **`/modules`** - Shared PowerShell functions

## Configuration File Patterns

When adding new dotfile modules:

1. Create a directory under the appropriate category (`/tools`, `/languages`, etc.)
2. Add a `dot.yaml` with platform-specific configuration
3. Include any config files to be symlinked
4. Define dependencies in the `depends` section
5. Use templating for platform-specific paths: `{{ env.LOCALAPPDATA }}`

Example `dot.yaml` structure:

```yaml
linux[whoami.distro^="Arch"]:
  installs:
    cmd: yes | sudo pacman -S package-name
    depends:
      - /tools/dependency
  links:
    config.conf: ~/.config/app/config.conf
```

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: `npx openskills read <skill-name>` (run in your shell)
  - For multiple: `npx openskills read skill-one,skill-two`
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>brand-guidelines</name>
<description>Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. Use it when brand colors or style guidelines, visual formatting, or company design standards apply.</description>
<location>project</location>
</skill>

<skill>
<name>canvas-design</name>
<description>Create beautiful visual art in .png and .pdf documents using design philosophy. You should use this skill when the user asks to create a poster, piece of art, design, or other static piece. Create original visual designs, never copying existing artists' work to avoid copyright violations.</description>
<location>project</location>
</skill>

<skill>
<name>doc-coauthoring</name>
<description>Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks.</description>
<location>project</location>
</skill>

<skill>
<name>docx</name>
<description>"Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files). Triggers include: any mention of 'Word doc', 'word document', '.docx', or requests to produce professional documents with formatting like tables of contents, headings, page numbers, or letterheads. Also use when extracting or reorganizing content from .docx files, inserting or replacing images in documents, performing find-and-replace in Word files, working with tracked changes or comments, or converting content into a polished Word document. If the user asks for a 'report', 'memo', 'letter', 'template', or similar deliverable as a Word or .docx file, use this skill. Do NOT use for PDFs, spreadsheets, Google Docs, or general coding tasks unrelated to document generation."</description>
<location>project</location>
</skill>

<skill>
<name>frontend-design</name>
<description>Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.</description>
<location>project</location>
</skill>

<skill>
<name>internal-comms</name>
<description>A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use. Claude should use this skill whenever asked to write some sort of internal communications (status reports, leadership updates, 3P updates, company newsletters, FAQs, incident reports, project updates, etc.).</description>
<location>project</location>
</skill>

<skill>
<name>pdf</name>
<description>Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. If the user mentions a .pdf file or asks to produce one, use this skill.</description>
<location>project</location>
</skill>

<skill>
<name>skill-creator</name>
<description>Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.</description>
<location>project</location>
</skill>

<skill>
<name>template</name>
<description>Replace with description of the skill and when Claude should use it.</description>
<location>project</location>
</skill>

<skill>
<name>webapp-testing</name>
<description>Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.</description>
<location>project</location>
</skill>

<skill>
<name>xlsx</name>
<description>"Use this skill any time a spreadsheet file is the primary input or output. This means any task where the user wants to: open, read, edit, or fix an existing .xlsx, .xlsm, .csv, or .tsv file (e.g., adding columns, computing formulas, formatting, charting, cleaning messy data); create a new spreadsheet from scratch or from other data sources; or convert between tabular file formats. Trigger especially when the user references a spreadsheet file by name or path — even casually (like \"the xlsx in my downloads\") — and wants something done to it or produced from it. Also trigger for cleaning or restructuring messy tabular data files (malformed rows, misplaced headers, junk data) into proper spreadsheets. The deliverable must be a spreadsheet file. Do NOT trigger when the primary deliverable is a Word document, HTML report, standalone Python script, database pipeline, or Google Sheets API integration, even if tabular data is involved."</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
