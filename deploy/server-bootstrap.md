# Server bootstrap (one-time, manual)

Target: Ubuntu 22.04+ LTS, 2 vCPU / 4 GB RAM minimum.

## 1. Install Docker

    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    # log out / back in so the group takes effect

## 2. Create the deploy user (optional but recommended)

    sudo adduser --disabled-password --gecos "" deploy
    sudo usermod -aG docker deploy
    sudo mkdir -p /home/deploy/.ssh
    # Paste the GitHub Actions deploy key's public half into:
    sudo nano /home/deploy/.ssh/authorized_keys
    sudo chown -R deploy:deploy /home/deploy/.ssh
    sudo chmod 700 /home/deploy/.ssh
    sudo chmod 600 /home/deploy/.ssh/authorized_keys

## 3. Working directory

    sudo mkdir -p /opt/brickfinder
    sudo chown deploy:deploy /opt/brickfinder
    su - deploy
    cd /opt/brickfinder

## 4. Drop in compose + .env

Copy `backend/docker-compose.prod.yml` (renamed `docker-compose.yml` on the server)
and `deploy/.env.prod.example` (renamed `.env`) into `/opt/brickfinder/`.

Fill in `.env`:
- `IMAGE_TAG` — `latest`
- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` — pick strong values

## 5. Huawei Cloud SWR login (one-time)

The image is hosted on Huawei Cloud SWR (Software Repository for Containers)
for fast pulls from mainland China. Login once so the server can pull images:

    docker login --username=<username> swr.cn-north-4.myhuaweicloud.com

Enter the password when prompted. Credentials are cached in `~/.docker/config.json`.

Generate the login credentials in the SWR console under "My Credentials" (访问凭证)
or use a long-term AK/SK to generate a login command.

## 6. First start

    cd /opt/brickfinder
    docker compose pull
    docker compose up -d
    curl -s localhost:8000/health

Expected: `{"status":"ok"}`. Now point a reverse proxy (Caddy/Nginx) at
`localhost:8000` if you want TLS — out of scope for M1.

## 7. GitHub repo secrets

In your GitHub repo → Settings → Secrets and variables → Actions, add:

| Secret name               | Value |
|---------------------------|-------|
| `DEPLOY_HOST`             | server IP / hostname |
| `DEPLOY_USER`             | `deploy` |
| `DEPLOY_SSH_KEY`          | private half of the SSH key whose public half is in `~deploy/.ssh/authorized_keys` |
| `DEPLOY_PORT`             | `22` (or your custom port) |
| `SWR_USERNAME` | your Huawei Cloud SWR username |
| `SWR_PASSWORD` | your Huawei Cloud SWR password |
