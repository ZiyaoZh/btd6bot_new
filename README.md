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

The container keeps NapCat and NcatBot in one process environment. Runtime files
are mounted under `runtime/`, including QQ login state, NcatBot logs/data, and
plugin data/log output.

## Update

```bash
git pull
git submodule update --init --recursive
docker compose up -d --build
```
