$env:EDITOR = 'nvim'

# Allow setting themes
$env:EZA_CONFIG_DIR = "$env:USERPROFILE\.config\eza"

# Use the same aliases as zsh-eza
# https://github.com/z-shell/zsh-eza?tab=readme-ov-file#aliases

Remove-Item -Path Alias:ls -ErrorAction SilentlyContinue
function ls { eza --hyperlink $args }

function l { eza --git-ignore --hyperlink $args }
function ll { eza --all --header --long --hyperlink $args }
function llm { eza --all --header --long --sort=modified --hyperlink $args }
function la { eza -lbhHigUmuSa $args }
function lx { eza -lbhHigUmuSa@ $args } # The '@' flag adds extended file attributes
function lt { eza --tree --hyperlink $args }
function tree { eza --tree --hyperlink $args }
