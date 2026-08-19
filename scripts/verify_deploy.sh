#!/usr/bin/env bash
set -euo pipefail

required_paths=(
  "config.yaml"
  ".env"
  "scripts/privoxy.conf"
  "scripts/ssh-proxy-entrypoint.sh"
  "plugins/btd6bot_plugin/manifest.toml"
  "plugins/btd6bot_plugin/btd6_api_processor/btd6_cli.py"
  "plugins/btd6bot_plugin/btd6_knowledge_base/knowledge_docs"
  "plugins/btd6bot_plugin/ChatMonkeyTD/main.py"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "missing required path: $path" >&2
    exit 1
  fi
done

configured_ssh_key_path="$({ awk -F= '$1 == "SSH_PROXY_KEY_PATH" {sub(/^[^=]*=/, ""); print; exit}' .env; } || true)"
configured_ssh_known_hosts_path="$({ awk -F= '$1 == "SSH_PROXY_KNOWN_HOSTS_PATH" {sub(/^[^=]*=/, ""); print; exit}' .env; } || true)"
configured_ssh_target="$({ awk -F= '$1 == "SSH_PROXY_TARGET" {sub(/^[^=]*=/, ""); print; exit}' .env; } || true)"
ssh_key_path="${SSH_PROXY_KEY_PATH:-$configured_ssh_key_path}"
ssh_known_hosts_path="${SSH_PROXY_KNOWN_HOSTS_PATH:-$configured_ssh_known_hosts_path}"
ssh_target="${SSH_PROXY_TARGET:-$configured_ssh_target}"

for variable in ssh_key_path ssh_known_hosts_path ssh_target; do
  if [[ -z "${!variable}" ]]; then
    echo "missing SSH proxy setting: $variable" >&2
    exit 1
  fi
done

for path in "$ssh_key_path" "$ssh_known_hosts_path"; do
  if [[ ! -r "$path" ]]; then
    echo "missing readable SSH proxy credential on the Docker host: $path" >&2
    exit 1
  fi
done

if ! ssh \
  -F /dev/null \
  -i "$ssh_key_path" \
  -o BatchMode=yes \
  -o ConnectTimeout=8 \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$ssh_known_hosts_path" \
  "$ssh_target" true; then
  echo "unable to establish the SSH proxy connection: $ssh_target" >&2
  exit 1
fi

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
