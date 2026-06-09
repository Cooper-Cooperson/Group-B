# Group-B — SuitIT Infrastructure

A self-hosted, open-source productivity suite for 50–100 users built on a single OVHcloud server.  
All services share a centralised identity layer (Keycloak) and are routed through a single Caddy reverse-proxy.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Repository Layout](#2-repository-layout)
3. [Infrastructure (Terraform)](#3-infrastructure-terraform)
4. [Ansible — Core Services](#4-ansible--core-services)
5. [Ansible — Services Deployment](#5-ansible--services-deployment)
6. [Docker Network Design](#6-docker-network-design)
7. [Authentication Flow](#7-authentication-flow)
8. [Service Integration Map](#8-service-integration-map)
9. [Deployment Order](#9-deployment-order)
10. [Key Variables Reference](#10-key-variables-reference)

---

## 1. Architecture Overview

```
Internet
    │
    ▼
OVH Edge Firewall  (stateful ingress rules — ports 22/80/443/25/587/993/10000)
    │
    ▼
Server  57.129.56.178
    │
    ▼
Caddy  :80 / :443  ──────────────────────────────────────────────────────┐
    │                                                                     │
    ├── suitit.tech / www  ──► portal-oauth-proxy  ──► Nginx (portal)    │
    ├── chat.suitit.tech   ──► Mattermost :8065                          │
    ├── meet.suitit.tech   ──► jitsi-oauth-proxy   ──► Jitsi Web         │
    ├── mail.suitit.tech   ──► Mailcow UI :8443 (host)                   │
    ├── files.suitit.tech  ──► ONLYOFFICE :8083 (JWT-protected)          │
    ├── seafile.suitit.tech──► Seafile :80                               │
    └── auth.suitit.tech   ──► Redirect → sso.suitit.tech               │
                                                                          │
Keycloak  (separate VM — sso.suitit.tech)  ◄──────────────── OIDC auth ─┘
```

**All HTTPS termination** happens at Caddy. Let's Encrypt certificates are obtained automatically.  
**All identity** is handled by Keycloak; every service holds only an OIDC client ID + secret.

---

## 2. Repository Layout

```
Group-B/
├── infra/                  # Terraform — main server, firewall, DNS, S3 storage
├── keycloak/               # Terraform — Keycloak VM + private network
├── ansible/                # Ansible — Mailcow, ONLYOFFICE, Seafile
│   ├── site.yml            #   top-level playbook
│   ├── inventory/
│   │   ├── hosts.yml       #   host groups: mailserver / appserver
│   │   └── group_vars/
│   │       └── all.yml     #   global variables (domains, secrets, OIDC config)
│   └── roles/
│       ├── docker/         #   install Docker Engine + Compose plugin
│       ├── mailcow/        #   email stack (Mailcow Dockerized)
│       ├── onlyoffice/     #   document editing + oauth2-proxy sidecar
│       └── seafile/        #   file storage + OIDC + OnlyOffice integration
│
└── services/               # Docker Compose stacks for Caddy, Portal, Mattermost, Jitsi
    ├── docker-compose.base.yml  # Caddy + Portal (nginx + oauth2-proxy)
    ├── caddy/Caddyfile          # Reverse-proxy routing rules
    ├── portal/index.html        # Landing page listing all services
    ├── mattermost/              # Team chat + PostgreSQL
    └── jitsi/                   # Video conferencing + XMPP mesh
```

> The `ansible/services/` subdirectory is a **separate Ansible project** that automates deploying
> everything inside `services/` onto the server. It has its own inventory, group_vars, and roles.

---

## 3. Infrastructure (Terraform)

### `infra/` — Main Server

| Resource | Purpose |
|---|---|
| `ovh_cloud_project_instance` | b2-30 VM (8 vCPU / 30 GB RAM) running Ubuntu |
| `ovh_ip_firewall` | Stateful edge firewall on the public IP |
| `ovh_ip_firewall_rule` | 20-rule sequence (see table below) |
| `ovh_domain_zone_record` | DNS A-records for all service subdomains |
| `ovh_cloud_project_storage` | S3-compatible object storage (Seafile backend) |

**Firewall rule sequence**

| Seq | Port / Protocol | Source | Action |
|---|---|---|---|
| 0–4 | TCP 22 (SSH) | Admin IP whitelist | PERMIT |
| 5 | TCP 80 | Any | PERMIT (ACME + HTTP→HTTPS) |
| 6 | TCP 443 | Any | PERMIT |
| 7–11 | TCP 25/465/587/143/993 | Any | PERMIT (email) |
| 12 | UDP 10000 | Any | PERMIT (Jitsi WebRTC) |
| 18 | TCP (established) | Any | PERMIT (return traffic) |
| 19 | TCP | Any | DENY (default drop) |

### `keycloak/` — Identity Server

Keycloak runs on a **separate VM** connected via a private VLAN (192.168.168.0/24).  
A cloud-init script bootstraps Docker, deploys Keycloak in dev mode, and puts Caddy in front for automatic TLS.

```
keycloak VM
├── Keycloak  (quay.io/keycloak/keycloak)   — internal :8080
└── Caddy                                   — public :443 → sso.suitit.tech
```

---

## 4. Ansible — Core Services

**Entry point:** `ansible/site.yml`

```yaml
Play 1 → mailserver group
  roles: docker → mailcow

Play 2 → appserver group
  roles: docker → onlyoffice

Play 3 → appserver group
  roles: seafile
```

### Role: `docker`

Idempotently installs the Docker Engine + Compose plugin on Ubuntu.

Key steps beyond the standard install:
- **Enables IPv6** — required to avoid OVH network routing issues.
- **Forces DNS IPv4 preference** — prevents GitHub timeout failures during image pulls.

### Role: `mailcow`

Deploys the Mailcow Dockerized email suite.

```
1. Fix MTU fragmentation (OVH TLS quirk — set eth0 MTU to 1400)
2. git clone mailcow-dockerized → /opt/mailcow-dockerized
3. Generate mailcow.conf (MAILCOW_HOSTNAME, TZ)
4. docker compose up -d
```

No custom templates — Mailcow generates its own config via `generate_config.sh`.

### Role: `onlyoffice`

Deploys two containers on the `proxy-net` Docker network:

```
onlyoffice-documentserver   (onlyoffice/documentserver:latest)
    ENV: JWT_ENABLED=true, JWT_SECRET=<shared>, DS_PORT=8083
    Volumes: data, logs, lib, fonts

onlyoffice-oauth-proxy      (oauth2-proxy:v7.6.0)
    ENV: OIDC issuer = Keycloak, client = "OnlyOffice"
    Upstream → onlyoffice-documentserver:8083
```

The oauth2-proxy sits **in front** of the document server so only authenticated users can reach the editor UI.  
Caddy routes `files.suitit.tech` directly to this proxy.

**JWT note:** The JWT secret must match the value in `seahub_settings.py` so Seafile can call the ONLYOFFICE API without user interaction.

### Role: `seafile`

The most complex role — deploys three containers and injects configuration into a running container.

```
db            (mariadb:10.11)      — seafile-net only
memcached     (memcached:1.6)      — seafile-net only
seafile-mc    (seafileltd/seafile-mc:11.0-latest)
              — seafile-net (db/cache) + proxy-net (Caddy)
```

**Post-deploy configuration injection (tasks 5–8):**

Because Seafile's OIDC and OnlyOffice settings live inside `seahub_settings.py` rather than environment variables, the role:

1. Waits for `/opt/seafile/conf/seahub_settings.py` to be created by the first run.
2. Checks whether `ENABLE_OAUTH` is already present (idempotency guard).
3. Copies a rendered `seahub_settings_custom.py` into the container via `docker cp`.
4. Appends its content to the real `seahub_settings.py` inside the container.
5. Restarts the seafile service and health-checks the Seahub API.

**`seahub_settings.py` additions:**

```python
# Keycloak OIDC
ENABLE_OAUTH = True
OAUTH_CLIENT_ID = "Seafile"
OAUTH_AUTHORIZATION_URL = https://sso.suitit.tech/realms/SuitIT/protocol/openid-connect/auth
OAUTH_TOKEN_URL       = https://sso.suitit.tech/realms/SuitIT/protocol/openid-connect/token
OAUTH_USER_INFO_URL   = https://sso.suitit.tech/realms/SuitIT/protocol/openid-connect/userinfo
OAUTH_ATTRIBUTE_MAP   = { id: email, name: name, ... }
OAUTH_CREATE_UNKNOWN_USER  = True
OAUTH_ACTIVATE_USER_AFTER_CREATION = True

# OnlyOffice integration
ENABLE_ONLYOFFICE = True
ONLYOFFICE_APIJS_URL = "https://files.suitit.tech/web-apps/apps/api/documents/api.js"
ONLYOFFICE_EDIT_FILE_EXTENSION = (docx, pptx, xlsx)
ONLYOFFICE_JWT_SECRET = "<shared-with-onlyoffice-role>"
```

### Global Variables (`ansible/inventory/group_vars/all.yml`)

| Variable | Value | Used by |
|---|---|---|
| `mailcow_hostname` | mail.suitit.tech | mailcow role |
| `onlyoffice_domain` | files.suitit.tech | onlyoffice role + Caddyfile |
| `onlyoffice_jwt_secret` | `Ge5Zj...` | onlyoffice role AND seafile role (must match) |
| `seafile_domain` | seafile.suitit.tech | seafile role |
| `seafile_admin_email` | robbefontys@gmail.com | seafile role (first admin account) |
| `keycloak_url` | https://sso.suitit.tech | all OIDC roles |
| `keycloak_realm` | SuitIT | all OIDC roles |

---

## 5. Ansible — Services Deployment

**Entry point:** `ansible/services/site.yml`

```yaml
Play 1 → all hosts
  roles: docker → services
```

This playbook deploys the contents of the `services/` directory onto the server.

### Role: `services`

```
1. Create directories:
   /opt/services/caddy
   /opt/services/mattermost
   /opt/services/jitsi
   /opt/services/portal

2. Copy docker-compose files and static configs (Caddyfile, index.html)

3. Render .env files from Jinja2 templates
   (injects passwords and OIDC secrets from group_vars/all.yml)

4. Create proxy-net Docker network (if absent)

5. docker compose up -d  for each stack:
   → caddy + portal
   → mattermost
   → jitsi
```

### Services Variables (`ansible/services/inventory/group_vars/all.yml`)

| Variable | Purpose |
|---|---|
| `mm_db_password` | PostgreSQL password for Mattermost |
| `jicofo_auth_password` | XMPP auth for Jitsi Focus component |
| `jvb_auth_password` | XMPP auth for Jitsi Video Bridge |
| `portal_oidc_client_id/secret` | oauth2-proxy in front of portal |
| `mm_oidc_client_id/secret` | Mattermost "GitLab" OAuth provider |
| `jitsi_oidc_client_id/secret` | oauth2-proxy in front of Jitsi Web |
| `keycloak_url` / `keycloak_realm` | Shared across all OIDC configs |

### `.env.j2` Template

Each service stack that needs runtime secrets gets a `.env` rendered from this template.  
The Jinja2 variables map directly to the `group_vars/all.yml` keys above, so secrets never appear as plaintext in committed files.

---

## 6. Docker Network Design

```
proxy-net  (external, shared bridge)
  ├─ caddy
  ├─ portal-oauth-proxy
  ├─ portal-static
  ├─ mattermost
  ├─ jitsi-web + jitsi-oauth-proxy
  ├─ onlyoffice-documentserver + onlyoffice-oauth-proxy
  └─ seafile

seafile-net  (internal — no external routing)
  ├─ seafile-db  (MariaDB)
  └─ memcached

mm-internal  (internal — no external routing)
  └─ mattermost-db  (PostgreSQL)

jitsi-net  (internal — XMPP mesh)
  ├─ prosody  (XMPP server)
  ├─ jicofo   (Focus component)
  └─ jvb      (Video Bridge)
```

**Rule of thumb:**
- A container that needs to be reached by Caddy must be on `proxy-net`.
- Databases and internal components live on service-specific internal networks, invisible to Caddy.

---

## 7. Authentication Flow

```
Browser → https://<service>.suitit.tech
    │
    ▼
Caddy (TLS termination)
    │
    ▼  (for protected services)
oauth2-proxy
    │  cookie not present?
    ▼
Keycloak  (https://sso.suitit.tech/realms/SuitIT)
    │  user logs in
    ▼
oauth2-proxy receives ID token  →  sets session cookie
    │
    ▼
Upstream service (Mattermost / Jitsi / Portal / ONLYOFFICE)
```

**Mattermost exception:** Uses Keycloak via the GitLab OAuth provider shim rather than a generic OIDC proxy.  
Keycloak's `/openid-connect/` endpoints are compatible with GitLab's OAuth2 format.

**ONLYOFFICE exception:** Protected by oauth2-proxy for browser access, but Seafile calls the API directly using a shared JWT secret — no OIDC round-trip for document operations.

**Mailcow exception:** Caddy proxies to `host.docker.internal:8443` (the Mailcow UI port exposed on the host). Mailcow manages its own authentication internally.

---

## 8. Service Integration Map

```
Seafile  ──── ONLYOFFICE ────  JWT secret (must be identical in both)
   │                │
   └── OIDC ────────┘
          │
       Keycloak
          │
   ┌──────┼──────────────────────────┐
   │      │      │          │        │
Portal  Jitsi  Mattermost  Seafile  ONLYOFFICE
(oauth2) (oauth2) (GitLab shim) (direct OIDC) (oauth2)
```

All OIDC clients registered in Keycloak realm `SuitIT`:

| Client ID | Service | Auth method |
|---|---|---|
| Portal | Landing page | oauth2-proxy |
| mattermost | Mattermost | GitLab shim |
| Jitsi | Jitsi Meet | oauth2-proxy |
| Seafile | Seafile | Direct OIDC |
| OnlyOffice | ONLYOFFICE editor | oauth2-proxy |

---

## 9. Deployment Order

The steps must be run in order because each layer depends on the previous one.

```
Step 1 — terraform apply  (infra/)
          Provisions: server, public IP, firewall rules, DNS records, S3 bucket

Step 2 — terraform apply  (keycloak/)
          Provisions: Keycloak VM, private network, sso.suitit.tech DNS record
          Cloud-init bootstraps Docker + Keycloak + Caddy automatically

Step 3 — (Manual) Configure Keycloak
          Create realm "SuitIT", add OIDC clients for all services,
          record client IDs and secrets into ansible group_vars/all.yml

Step 4 — ansible-playbook ansible/site.yml
          Deploys: Mailcow (mailserver), ONLYOFFICE (appserver), Seafile (appserver)
          Injects OIDC + JWT config into running containers

Step 5 — ansible-playbook ansible/services/site.yml
          Deploys: Docker, Caddy, Portal, Mattermost, Jitsi
          Renders .env files from templates, creates proxy-net, starts all stacks
```

---

## 10. Key Variables Reference

### Shared Secrets (must be consistent across roles)

| Secret | Where set | Where consumed |
|---|---|---|
| `onlyoffice_jwt_secret` | `ansible/inventory/group_vars/all.yml` | onlyoffice role (JWT_SECRET env) + seafile role (seahub_settings.py) |
| Keycloak client secrets | `ansible/*/inventory/group_vars/all.yml` | Each oauth2-proxy / service config |

### Domain Map

| Subdomain | Service |
|---|---|
| suitit.tech / www | Portal (oauth2-proxy → Nginx) |
| sso.suitit.tech | Keycloak (separate VM) |
| mail.suitit.tech | Mailcow |
| chat.suitit.tech | Mattermost |
| meet.suitit.tech | Jitsi Meet |
| files.suitit.tech | ONLYOFFICE Document Server |
| seafile.suitit.tech | Seafile |

### Template Files

| Template | Rendered to | Key injections |
|---|---|---|
| `roles/onlyoffice/templates/docker-compose.yml.j2` | `/opt/onlyoffice/docker-compose.yml` | JWT secret, Keycloak OIDC URLs, domain |
| `roles/seafile/templates/docker-compose.yml.j2` | `/opt/seafile/docker-compose.yml` | DB password, admin credentials, domain |
| `roles/seafile/templates/seahub_settings.py.j2` | Injected into running container | OIDC config, OnlyOffice JWT + URL |
| `ansible/services/roles/services/templates/.env.j2` | `/opt/services/<svc>/.env` | DB passwords, Jitsi component passwords, OIDC secrets |
