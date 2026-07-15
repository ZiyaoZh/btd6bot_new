#!/bin/sh
set -eu

: "${SSH_TARGET:?SSH_TARGET is required}"
SOCKS_LISTEN_PORT=1080
HTTP_PROXY_LISTEN_PORT=8118
SSH_KEY_FILE=/run/secrets/ssh_proxy_key
SSH_KNOWN_HOSTS_FILE=/run/secrets/ssh_proxy_known_hosts
ssh_pid=""
privoxy_pid=""

if [ ! -r "$SSH_KEY_FILE" ]; then
    echo "SSH private key is not readable: $SSH_KEY_FILE" >&2
    exit 1
fi

if ! ssh-keygen -y -f "$SSH_KEY_FILE" >/dev/null 2>&1; then
    echo "SSH private key cannot be opened or parsed: $SSH_KEY_FILE" >&2
    exit 1
fi

if [ ! -r "$SSH_KNOWN_HOSTS_FILE" ]; then
    echo "SSH known_hosts is not readable: $SSH_KNOWN_HOSTS_FILE" >&2
    exit 1
fi

cleanup() {
    trap - EXIT INT TERM
    if [ -n "$ssh_pid" ]; then
        kill "$ssh_pid" 2>/dev/null || true
        wait "$ssh_pid" 2>/dev/null || true
    fi
    if [ -n "$privoxy_pid" ]; then
        kill "$privoxy_pid" 2>/dev/null || true
        wait "$privoxy_pid" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

ssh \
    -F /dev/null \
    -NT \
    -i "$SSH_KEY_FILE" \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    -o ExitOnForwardFailure=yes \
    -o IdentitiesOnly=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$SSH_KNOWN_HOSTS_FILE" \
    -D "0.0.0.0:${SOCKS_LISTEN_PORT}" \
    "$SSH_TARGET" &
ssh_pid=$!

proxy_ready=0
for _ in $(seq 1 50); do
    if ! kill -0 "$ssh_pid" 2>/dev/null; then
        echo "SSH proxy process exited during startup" >&2
        exit 1
    fi
    if nc -z 127.0.0.1 "$SOCKS_LISTEN_PORT" >/dev/null 2>&1; then
        proxy_ready=1
        break
    fi
    sleep 0.2
done

if [ "$proxy_ready" -ne 1 ]; then
    echo "SSH SOCKS proxy did not become ready" >&2
    exit 1
fi

privoxy --no-daemon /etc/privoxy/config &
privoxy_pid=$!

echo "SSH SOCKS proxy listening on :${SOCKS_LISTEN_PORT} via ${SSH_TARGET}"
echo "HTTP CONNECT proxy listening on :${HTTP_PROXY_LISTEN_PORT}"

while kill -0 "$ssh_pid" 2>/dev/null && kill -0 "$privoxy_pid" 2>/dev/null; do
    sleep 2
done

echo "SSH or HTTP proxy process exited" >&2
exit 1
