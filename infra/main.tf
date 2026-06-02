/*
=============================================================================
Escaping Microsoft — Main Terraform Configuration
=============================================================================
Provisions the complete network and security infrastructure on OVHcloud
for a self-hosted Microsoft 365 replacement (50-100 users).
Resources provisioned:
1. Compute instance   (ovh_cloud_project_instance)
2. IP Firewall        (ovh_ip_firewall + ovh_ip_firewall_rule)
3. DNS A-records      (ovh_domain_zone_record)
CI/CD: Deployed via GitHub Actions (Cooper-Cooperson/Group-B)
Secrets injected as TF_VAR_* environment variables.
=============================================================================
-----------------------------------------------------------------------------
Terraform Settings & Provider Requirements
Using ONLY the official ovh/ovh provider for all resources.
-----------------------------------------------------------------------------
*/
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    ovh = {
      source = "ovh/ovh"
      version = ">= 2.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }
}

/*
-----------------------------------------------------------------------------
OVH Provider — Authenticated via GitHub Actions secrets
Manages: DNS zones, cloud instances, IP firewalls
Docs: https://registry.terraform.io/providers/ovh/ovh/latest/docs
-----------------------------------------------------------------------------
*/
provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

/*
=============================================================================
SECTION 1: COMPUTE INSTANCE
=============================================================================
Single-node server running the entire stack via Docker Compose:
• Keycloak     (auth.suitit.nl)   — IAM / SSO
• Nextcloud    (files.suitit.nl)  — File storage & collaboration
• Mailcow      (mail.suitit.nl)   — Email server
• Mattermost   (chat.suitit.nl)   — Team messaging
• Jitsi Meet   (meet.suitit.nl)   — Video conferencing
• Traefik/Nginx                  — Reverse proxy + TLS termination
=============================================================================
*/

resource "ovh_cloud_project_instance" "server" {
  service_name   = var.ovh_project_id
  name           = var.instance_name
  region         = var.region
  billing_period = "hourly"

  flavor {
    flavor_id = var.instance_flavor
  }

  boot_from {
    image_id = var.instance_image
  }

  network {
    public = true
  }

  ssh_key {
    name = var.ssh_keypair_name
  }

  lifecycle {
    ignore_changes = all
  }
}


/*
Extract the public IPv4 address from the instance's address list
*/

locals {
  public_ipv4 = [
    for addr in ovh_cloud_project_instance.server.addresses :
    addr.ip if addr.version == 4
  ][0]
}

/*
=============================================================================
SECTION 2: IP FIREWALL (Ingress Rules)
=============================================================================
OVH IP Firewall operates at the OVH network edge (before traffic reaches
the instance). It is an ingress-only, stateful firewall.
Rule layout (sequence 0–19, max 20 rules):
┌──────────┬──────────────────────────────────────────────────────────┐
│ Seq 0–4  │ SSH (22/TCP) — restricted to admin IP whitelist         │
│ Seq 5    │ HTTP (80/TCP) — web services + Let's Encrypt ACME       │
│ Seq 6    │ HTTPS (443/TCP) — all web services (TLS)                │
│ Seq 7    │ SMTP (25/TCP) — inbound email delivery                  │
│ Seq 8    │ SMTPS (465/TCP) — implicit TLS mail submission          │
│ Seq 9    │ Submission (587/TCP) — STARTTLS mail submission         │
│ Seq 10   │ IMAP (143/TCP) — email client access                   │
│ Seq 11   │ IMAPS (993/TCP) — encrypted IMAP                       │
│ Seq 12   │ Jitsi (10000/UDP) — WebRTC video/audio media           │
│ Seq 13–18│ Reserved for future services                            │
│ Seq 19   │ DENY ALL TCP (catch-all for least privilege)            │
└──────────┴──────────────────────────────────────────────────────────┘
EGRESS: OVH IP Firewall is ingress-only. All outbound traffic is allowed
by default — no egress rules needed (system updates, SMTP out, API calls
all work without additional configuration).
=============================================================================
Enable the IP Firewall on the server's public IP
*/

resource "ovh_ip_firewall" "server" {
  depends_on = [ovh_cloud_project_instance.server]

  ip             = local.public_ipv4
  ip_on_firewall = local.public_ipv4
  enabled        = true
}

/*
-----------------------------------------------------------------------------
Seq 0–4: SSH (Port 22/TCP) — Admin IP Whitelist Only
Each admin IP gets its own rule with a unique sequence number.
Controlled by var.admin_ip_whitelist (max 5 entries, validated).
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "ssh_admin" {
  for_each = { for idx, cidr in var.admin_ip_whitelist : tostring(idx) => cidr }

  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = tonumber(each.key) /* Sequences 0, 1, 2, ... up to 4 */
  destination_port = "22"
  source           = each.value /* e.g., "203.0.113.42/32" */
}

/*
-----------------------------------------------------------------------------
Seq 5: HTTP (Port 80/TCP) — Open to All
Used by: Nextcloud, Keycloak, Mattermost, Jitsi web UI
Also required for Let's Encrypt ACME HTTP-01 challenge validation.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "http" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 5
  destination_port = "80"
}

/*
-----------------------------------------------------------------------------
Seq 6: HTTPS (Port 443/TCP) — Open to All
Primary entry point for all web services behind the reverse proxy.
Handles TLS-encrypted traffic for all subdomains.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "https" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 6
  destination_port = "443"
}

/*
-----------------------------------------------------------------------------
Seq 16: HTTPS-ALT (Port 8443/TCP) — Temporary Mailcow UI
Temporary access for Mailcow UI until Caddy is installed.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "https_alt" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 16
  destination_port = "8443"
}

/*
-----------------------------------------------------------------------------
Seq 7: SMTP (Port 25/TCP) — Open to All
Inbound email delivery. Mailcow must receive mail from any MTA on the
internet. Blocking this would prevent receiving emails entirely.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "smtp" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 7
  destination_port = "25"
}

/*
-----------------------------------------------------------------------------
Seq 8: SMTPS (Port 465/TCP) — Open to All
Implicit TLS for mail submission from email clients (Thunderbird, etc.).
Users connect from any network, so this must be publicly accessible.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "smtps" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 8
  destination_port = "465"
}

/*
-----------------------------------------------------------------------------
Seq 9: Submission (Port 587/TCP) — Open to All
STARTTLS mail submission from email clients. Standard port for
authenticated outbound email from user mail apps.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "submission" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 9
  destination_port = "587"
}

/*
-----------------------------------------------------------------------------
Seq 10: IMAP (Port 143/TCP) — Open to All
Plaintext/STARTTLS IMAP for email client access.
Users connect from various networks (home, mobile, etc.).
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "imap" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 10
  destination_port = "143"
}

/*
-----------------------------------------------------------------------------
Seq 11: IMAPS (Port 993/TCP) — Open to All
Implicit TLS IMAP — the secure, recommended protocol for email clients.
Should be preferred over port 143 by all modern clients.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "imaps" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "tcp"
  sequence         = 11
  destination_port = "993"
}

/*
-----------------------------------------------------------------------------
Seq 12: Jitsi WebRTC (Port 10000/UDP) — Open to All
Used by Jitsi Videobridge (JVB) for real-time video/audio media streams.
MUST be UDP for acceptable latency in video conferencing.
Participants join from any network.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "jitsi_webrtc" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "udp"
  sequence         = 12
  destination_port = "10000"
}

/*
-----------------------------------------------------------------------------
Seq 13: WireGuard VPN (Port 51820/UDP) — Restricted to pfSense WAN IP
Allows the on-premise pfSense router on ESXi to build a secure tunnel 
directly to the single-node server.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "wireguard_vpn" {
  depends_on = [ovh_ip_firewall.server]

  ip               = local.public_ipv4
  ip_on_firewall   = local.public_ipv4
  action           = "permit"
  protocol         = "udp"
  sequence         = 13
  destination_port = "51820"
  source           = var.pfsense_public_ip
}

/*
-----------------------------------------------------------------------------
Seq 18: Permit Established TCP Connections
Required so that outbound connections (apt, git, curl) can receive return traffic.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "permit_established_tcp" {
  depends_on = [ovh_ip_firewall.server]

  ip             = local.public_ipv4
  ip_on_firewall = local.public_ipv4
  action         = "permit"
  protocol       = "tcp"
  sequence       = 18
  tcp_option     = "established"
}

/*
-----------------------------------------------------------------------------
Seq 19: Default DENY — Catch-All for TCP
Implements least-privilege: any TCP traffic not explicitly permitted above
is denied at the OVH network edge.
-----------------------------------------------------------------------------
*/
resource "ovh_ip_firewall_rule" "deny_all_tcp" {
  depends_on = [ovh_ip_firewall.server]

  ip             = local.public_ipv4
  ip_on_firewall = local.public_ipv4
  action         = "deny"
  protocol       = "tcp"
  sequence       = 19
}

/*
=============================================================================
SECTION 3: DNS A-RECORDS
=============================================================================
Maps each service subdomain to the server's public IPv4 address.
All records are created dynamically from var.subdomains — adding a new
service is a one-line change in variables.tf.
Prerequisites:
• Domain must be registered and managed via OVHcloud DNS.
• Do NOT mix manual DNS changes in OVHcloud Panel with Terraform
to avoid state drift.
Records created:
auth.<domain>   → Keycloak (IAM / SSO)
files.<domain>  → Nextcloud (File Storage)
mail.<domain>   → Mailcow (Email)
chat.<domain>   → Mattermost (Team Chat)
meet.<domain>   → Jitsi Meet (Video Conferencing)
=============================================================================
*/
resource "ovh_domain_zone_record" "services" {
  for_each = var.subdomains

  zone      = var.domain
  subdomain = each.key
  fieldtype = "A"
  ttl       = var.dns_ttl
  target    = local.public_ipv4
}


