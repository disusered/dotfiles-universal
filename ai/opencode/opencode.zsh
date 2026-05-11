export PATH=/home/carlos/.opencode/bin:$PATH

opencode-init() {
  op read "op://Personal/GLM Coding Plan/password" > ~/.config/opencode/.zai-key
  chmod 600 ~/.config/opencode/.zai-key
}
