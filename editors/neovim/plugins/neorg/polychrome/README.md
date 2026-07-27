# Polychrome Neorg capture integration

This staging tree targets the installed Neorg `v9.6.4-2-g1f14d72a`
(`1f14d72aad7165eac307a2a2f6be0fb97a04b3c2`, Norg `1.1.1`).

Install the local module directory at:

```text
~/.dotfiles/editors/neovim/plugins/neorg/polychrome/
```

Then apply `neorg.lua.patch` from the root of `~/.dotfiles`. The local Lazy
dependency puts the module's `lua/` directory on Neovim's runtime path before
Neorg loads `external.polychrome`.

The command `:Neorg polychrome black new` creates:

```text
black/entries/YYYY/MM/DD/HHMMSS[-NN].norg
```

Creation uses an exclusive libuv open (`wx`) with mode `0600`, so an existing
entry cannot be overwritten. New chronology directories use `0700`; existing
directories are not chmodded. Every created path is resolved against the
configured canonical Black root, and symlinked chronology components are
rejected. The new buffer opens with the cursor on the blank line between the
human-body sentinels. `<leader>ob` invokes the same command.

The outer `@document.meta` uses `polychrome_id`, `authors`, `categories`,
`created`, `updated`, `visibility`, and `version`. The exact standalone comment
sentinels are `%polychrome:black-body:start%`,
`%polychrome:black-body:end%`, `%polychrome:connections:start%`, and
`%polychrome:connections:end%`.

Run the isolated headless check with:

```sh
sh tests/run.sh
```

The test fixes the clock, creates three same-second entries, checks suffixing,
metadata and exact sentinels, exercises the actual `:Neorg` command, and parses
the result with the installed Norg and Norg-meta Tree-sitter parsers. Its
writable state is confined to a temporary directory.

Set `POLYCHROME_NEORG_SEED_ENTRY` to a migrated entry to additionally verify
that an imported document containing nested original `@document.meta` parses
without error and that Neorg reads the outer Polychrome metadata.
