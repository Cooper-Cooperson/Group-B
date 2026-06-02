# Communication Services — Person 3

Caddy reverse proxy + Mattermost + Jitsi Meet, deployed via Docker Compose on OVHcloud.

- `chat.suitit.tech` → Mattermost (replaces Teams chat)
- `meet.suitit.tech` → Jitsi Meet (replaces Teams video)

HTTPS is handled automatically by Caddy (Let's Encrypt). Only ports 80, 443, and UDP 10000 are exposed.

## Deploy

```bash
# 1. Create root .env with real values
cat > .env <<EOF
MM_DB_PASSWORD=<strong-password>
JICOFO_AUTH_PASSWORD=<strong-password>
JVB_AUTH_PASSWORD=<strong-password>
DOCKER_HOST_ADDRESS=<server-public-ip>
EOF

# 2. Start the stack
docker compose \
  --env-file .env \
  -f services/docker-compose.base.yml \
  -f services/mattermost/docker-compose.yml \
  -f services/jitsi/docker-compose.yml \
  up -d
```

## Verify

```bash
curl -I https://chat.suitit.tech  # 200 OK + valid cert
curl -I https://meet.suitit.tech  # 200 OK + valid cert
nmap -p 8065 <server-ip>        # should be filtered/closed
```
