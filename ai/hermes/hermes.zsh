hermes-init() {
  op inject -i ~/.hermes/env.tpl -o ~/.hermes/.env
  chmod 600 ~/.hermes/.env
}
