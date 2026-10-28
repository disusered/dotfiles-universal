# agy has no env setting, so select its signing key here.
agy() {
  GIT_CONFIG_GLOBAL="$HOME/.dotfiles/tools/git/agents/antigravity.gitconfig" command agy "$@"
}
