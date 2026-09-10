# Codex with DeepSeek

Open a new Zsh terminal and run:

```sh
codex-deepseek
```

For an existing terminal, first run:

```sh
source ~/.config/zsh/5006_codex_deepseek.zsh
```

The command reads `op://Personal/Deepseek/credential` at launch and selects
DeepSeek Flash through its native Responses API. It uses a separate Codex
profile and model catalog, with high reasoning effort and built-in web search
disabled. Arguments are forwarded to the existing `codex` wrapper.

The key is passed through the child environment, never saved in configuration.
Normal `codex` configuration and permissions stay unchanged.

The catalog comes from [DeepSeek's documented Codex integration](https://api-docs.deepseek.com/quick_start/agent_integrations/codex/),
retrieved September 10, 2026, with only Flash retained and its model identity
corrected. The profile uses `env_key` instead of storing the key inline.

Rotz links these files through `/ai/codex`. The launcher test is
`zsh ai/codex/tests/deepseek-launcher.test.zsh`.
