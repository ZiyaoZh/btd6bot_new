# btd6bot Docker deployment

This repository is the deployable wrapper for the NcatBot5 BTD6 bot.

It uses the official single-container `huanyp/ncatbot:latest` image, keeps
`plugins/btd6bot_plugin` as a git submodule, and lets that plugin manage its
own tool repositories as nested submodules.

## First checkout

```bash
git clone --recursive <deploy-repo-url> btd6bot-deploy
cd btd6bot-deploy
./scripts/bootstrap_submodules.sh
```

If the repository was cloned without `--recursive`, run:

```bash
git submodule update --init --recursive
```

## Configure

```bash
cp config.yaml.example config.yaml
cp .env.example .env
```

Edit `config.yaml` and `.env` with the production QQ account, administrator QQ,
NapCat token, target groups, and LLM credentials.

The Compose stack routes QQ and outbound HTTP traffic through an SSH tunnel.
Keep the SSH target, private-key path, and verified host key in local deployment
files; none of those values should be committed. Before starting the stack,
create the private trust-anchor file and fill in `.env`:

```bash
mkdir -p .private
cp scripts/ssh-proxy-known-hosts.example .private/ssh-proxy-known-hosts
```

Replace the placeholder in `.private/ssh-proxy-known-hosts` with the verified
public host-key line, then set `SSH_PROXY_KEY_PATH`,
`SSH_PROXY_KNOWN_HOSTS_PATH`, and `SSH_PROXY_TARGET` in `.env`. These paths refer
to the Docker host, not to a container that happens to mount this repository.

Verify that the configured key and trust anchor can establish a non-interactive
SSH connection:

```bash
./scripts/verify_deploy.sh
```

The proxy sidecar mounts only the configured private key and verified
`known_hosts` file, both read-only. Changing the proxy address requires
independently verifying and updating the private trust-anchor file.

Do not commit `config.yaml` or `.env`.

## Verify

```bash
./scripts/verify_deploy.sh
```

## Run

```bash
docker compose up -d --build
docker compose logs -f ncatbot
```

The `ssh-proxy` service exposes SOCKS port `1080` and HTTP CONNECT port `8118`
only inside the Compose network. NapCat uses SOCKS directly; Python HTTP and LLM
requests use the HTTP proxy. Confirm both services are healthy with:

```bash
docker compose ps
docker compose logs ssh-proxy
```

The container keeps NapCat and NcatBot in one process environment. Runtime files
are mounted under `runtime/`, including QQ login state, NcatBot logs/data, and
plugin data/log output.

## Update

```bash
git pull
git submodule update --init --recursive
docker compose up -d --build
```
