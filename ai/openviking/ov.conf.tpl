{
  "storage": {
    "workspace": "${HOME}/.local/share/openviking"
  },
  "embedding": {
    "dense": {
      "provider": "jina",
      "api_key": "${OPENVIKING_JINA_API_KEY}",
      "model": "jina-embeddings-v5-text-small",
      "dimension": 1024
    }
  },
  "vlm": {
    "provider": "openai",
    "api_base": "https://openrouter.ai/api/v1",
    "api_key": "${OPENVIKING_OPENROUTER_API_KEY}",
    "model": "qwen/qwen3.7-flash"
  },
  "server": {
    "host": "127.0.0.1",
    "port": 1933
  }
}
