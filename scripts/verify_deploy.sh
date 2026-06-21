#!/usr/bin/env bash
set -euo pipefail

required_paths=(
  "config.yaml"
  ".env"
  "plugins/btd6bot_plugin/manifest.toml"
  "plugins/btd6bot_plugin/btd6_api_processor/btd6_cli.py"
  "plugins/btd6bot_plugin/btd6_knowledge_base/search_index.db"
  "plugins/btd6bot_plugin/ChatMonkeyTD/main.py"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "missing required path: $path" >&2
    exit 1
  fi
done

if ! grep -q '^BOT_TARGET_GROUP_ID=' .env; then
  echo "missing BOT_TARGET_GROUP_ID in .env" >&2
  exit 1
fi

if ! grep -q '^LLM_API_KEY=' .env; then
  echo "missing LLM_API_KEY in .env" >&2
  exit 1
fi

docker compose config >/dev/null
echo "deploy verification passed"
