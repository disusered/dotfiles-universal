# pi has no env setting, so select its signing key here.
pi() {
  GIT_CONFIG_GLOBAL="$HOME/.dotfiles/tools/git/agents/pi.gitconfig" command pi "$@"
}
