# Services Deployment — Caddy + Mattermost + Jitsi

Automates Docker installation and deployment of the services stack on the server.

## Services

| Service | URL |
|---|---|
| Caddy (reverse proxy) | `chat.suitit.tech`, `meet.suitit.tech`, `mail.suitit.tech` |
| Mattermost | `chat.suitit.tech` |
| Jitsi Meet | `meet.suitit.tech` |

## What it does

1. Installs Docker on the server
2. Copies compose files and Caddyfile to `/opt/services/`
3. Creates the `proxy-net` Docker network
4. Starts Caddy, Mattermost and Jitsi

## Run

From the repo root inside WSL:

```bash
ansible-playbook -i ansible/services/inventory/hosts.yml ansible/services/site.yml
```
