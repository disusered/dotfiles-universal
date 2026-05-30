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
    "provider": "glm",
    "api_base": "https://api.z.ai/api/coding/paas/v4",
    "api_key": "${OPENVIKING_GLM_API_KEY}",
    "model": "glm-4.6v"
  },
  "server": {
    "host": "127.0.0.1",
    "port": 1933
  }
}
