# Neorg Treesitter Parser Manual Build

## Background

Neorg is not yet compatible with Treesitter 2.x, which requires manually building the parsers instead of using `:TSInstall`. Both `norg` and `norg_meta` parsers need to be built manually.

## Prerequisites

- tree-sitter CLI installed (via `pacman -S tree-sitter-cli` on Arch)
- Node.js and npm/pnpm
- Git

## Build Instructions

### Option 1: Using tree-sitter CLI

```bash
# Create a directory for the parser
mkdir -p ~/.local/share/nvim/tree-sitter-parsers
cd ~/.local/share/nvim/tree-sitter-parsers

# Clone the neorg parsers
git clone https://github.com/nvim-neorg/tree-sitter-norg.git
git clone https://github.com/nvim-neorg/tree-sitter-norg-meta.git

# Build norg parser
cd tree-sitter-norg
tree-sitter generate
tree-sitter build
# Copy the compiled parser to nvim's parser directory
mkdir -p ~/.local/share/nvim/site/parser
cp libtree-sitter-norg.so ~/.local/share/nvim/site/parser/norg.so

# Build norg_meta parser
cd ../tree-sitter-norg-meta
tree-sitter generate
tree-sitter build
cp libtree-sitter-norg-meta.so ~/.local/share/nvim/site/parser/norg_meta.so
```

### Option 2: Using nvim-treesitter's installer (from Neovim)

```vim
:lua require('nvim-treesitter.install').compilers = { 'clang' }
:TSInstallFromGrammar norg
:TSInstallFromGrammar norg_meta
```

## Verification

After building, verify the parsers are loaded:

```vim
:checkhealth nvim-treesitter
```

Look for `norg` and `norg_meta` in the parser list.

## Troubleshooting

### Parser not found

If Neovim can't find the parser:
- Check that the `.so` files are in `~/.local/share/nvim/site/parser/`
- Verify file names are exactly `norg.so` and `norg_meta.so` (not `libtree-sitter-norg.so`)
- Restart Neovim

### Build errors

If the build fails:
- Ensure you have a C compiler installed (`gcc` or `clang`)
- Try updating tree-sitter CLI: `pacman -S tree-sitter-cli`
- Check the tree-sitter-norg repository issues for known problems

## Future

Once Neorg is updated for Treesitter 2.x compatibility, these parsers can be added back to the `ensure_installed` list in `treesitter.lua` for automatic installation.
