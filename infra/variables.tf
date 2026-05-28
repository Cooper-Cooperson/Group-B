/*
=============================================================================
Escaping Microsoft — Input Variables
=============================================================================
These variables are injected by GitHub Actions via terraform.tfvars,
generated from repository secrets in Cooper-Cooperson/Group-B.
CI/CD Mapping:
GitHub Secret            → tfvars key                    → Terraform Variable
APPLICATION_KEY          → application_key                → var.application_key
APPLICATION_SECRET       → application_secret             → var.application_secret
CONSUMER_KEY             → consumer_key                   → var.consumer_key
ENDPOINT                 → endpoint                       → var.endpoint
OVH_PROJECT_ID           → ovh_project_id                 → var.ovh_project_id
REGION                   → region                         → var.region
OS_USERNAME              → os_username                    → var.os_username
OS_PASSWORD              → os_password                    → var.os_password
OS_PROJECT_NAME          → os_project_name                → var.os_project_name
OS_PROJECT_ID            → os_project_id                  → var.os_project_id
KEYCLOAK_ADMIN_USER      → keycloak_admin_user            → var.keycloak_admin_user
KEYCLOAK_ADMIN_PASSWORD  → keycloak_admin_password        → var.keycloak_admin_password
KEYCLOAK_HOSTNAME        → keycloak_hostname              → var.keycloak_hostname
DOMAIN                   → domain                         → var.domain
SSH_KEYPAIR_NAME         → ssh_keypair_name               → var.ssh_keypair_name
ADMIN_IP_WHITELIST       → admin_ip_whitelist             → var.admin_ip_whitelist
=============================================================================
*/

/*
-----------------------------------------------------------------------------
OVH API Credentials (injected by GitHub Actions)
These authenticate Terraform against the OVH API for DNS and firewall mgmt.
Generate at: https://api.ovh.com/createToken/
-----------------------------------------------------------------------------
*/
variable "application_key" {
  description = "OVH API application key (GitHub secret: APPLICATION_KEY)"
  type        = string
  sensitive   = true
}

variable "application_secret" {
  description = "OVH API application secret (GitHub secret: APPLICATION_SECRET)"
  type        = string
  sensitive   = true
}

variable "consumer_key" {
  description = "OVH API consumer key (GitHub secret: CONSUMER_KEY)"
  type        = string
  sensitive   = true
}

variable "endpoint" {
  description = "OVH API endpoint — ovh-eu, ovh-us, or ovh-ca (GitHub secret: ENDPOINT)"
  type        = string
  default     = "ovh-eu"
}

/*
-----------------------------------------------------------------------------
OVH Public Cloud Project (injected by GitHub Actions)
-----------------------------------------------------------------------------
*/
variable "ovh_project_id" {
  description = "OVH Public Cloud project ID (GitHub secret: OVH_PROJECT_ID)"
  type        = string
}

variable "region" {
  type        = string
}

/*
-----------------------------------------------------------------------------
OpenStack Credentials (injected by GitHub Actions)
Used by OVH provider when provisioning cloud resources (instances, networks,
Kubernetes clusters). Generated from OVH Public Cloud → Users & Roles.
⚠ NEVER hardcode the password — store it as a GitHub Actions secret.
-----------------------------------------------------------------------------
*/
variable "os_username" {
  description = "OpenStack username (GitHub secret: OS_USERNAME)"
  type        = string
  default     = "user-632VJcwex6A8"
}

variable "os_password" {
  description = "OpenStack password (GitHub secret: OS_PASSWORD) — NEVER hardcode!"
  type        = string
  sensitive   = true
}

variable "os_project_name" {
  description = "OpenStack project name (GitHub secret: OS_PROJECT_NAME)"
  type        = string
  default     = "Project Group B SuitIT"
}

variable "os_project_id" {
  description = "OpenStack project ID (GitHub secret: OS_PROJECT_ID)"
  type        = string
  default     = "3696d7540bf640e8aaa3a4bed6946ec7"
}

/*
-----------------------------------------------------------------------------
Compute Instance Configuration
These can be set as additional GitHub secrets or have sensible defaults.
Sizing for 50-100 users running the full open-source stack:
b2-30  (8 vCPU, 30 GB RAM)  — recommended for production
b2-15  (4 vCPU, 15 GB RAM)  — minimum viable option
-----------------------------------------------------------------------------
*/
variable "instance_name" {
  description = "Hostname for the compute instance"
  type        = string
  default     = "escaping-microsoft-srv"
}

variable "instance_flavor" {
  description = "OVHcloud instance flavor ID (e.g., b2-15, b2-30, b2-60)"
  type        = string
  default     = "96848ff8-5da7-4a79-9922-74e1a0d64429"
}

variable "instance_image" {
  description = "OS image  UUID (Ubuntu recommended for Docker Compose)"
  type        = string
  default     = "d8ed87d0-1944-4f20-9108-cf21028ab9ba"
}

variable "ssh_keypair_name" {
  description = "Name of the SSH key pair already registered in your OVHcloud project"
  type        = string
}

/*
-----------------------------------------------------------------------------
DNS / Domain Configuration
The root domain must already be registered and managed via OVHcloud DNS.
Set as a GitHub secret or TF_VAR_domain in your workflow.
-----------------------------------------------------------------------------
*/
variable "domain" {
  description = "Root domain name managed in OVHcloud DNS (e.g., suitit.nl)"
  type        = string
}

variable "dns_ttl" {
  description = "TTL (in seconds) for DNS A-records. Lower to 300 during initial testing."
  type        = number
  default     = 3600
}

/*
Service subdomains — add new services here (one-line change)
*/
variable "subdomains" {
  description = "Map of service subdomains to their description (used for DNS A-records)"
  type        = map(string)
  default = {
    "auth"  = "Keycloak — Identity & Access Management (IAM)"
    "files" = "Nextcloud — File Storage & Collaboration"
    "mail"  = "Mailcow — Email Server (SMTP/IMAP)"
    "chat"  = "Mattermost — Team Chat & Messaging"
    "meet"  = "Jitsi Meet — Video Conferencing"
  }
}

/*
-----------------------------------------------------------------------------
Firewall — Admin SSH Access Whitelist
IMPORTANT: Restrict SSH to known admin IPs only (principle of least privilege).
Max 5 entries — the OVH IP Firewall supports 20 rules total; 5 are reserved
for SSH and the rest for service ports.
Set as TF_VAR_admin_ip_whitelist='["x.x.x.x/32"]' in your GitHub workflow.
-----------------------------------------------------------------------------
*/
variable "admin_ip_whitelist" {
  description = "List of CIDR blocks allowed SSH access (port 22). Example: ['203.0.113.10/32', '198.51.100.0/24']WARNING: Never set this to ['0.0.0.0/0'] in production!"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # ⚠ TESTING ONLY — replace with real admin IPs before production!

  validation {
    condition     = length(var.admin_ip_whitelist) > 0
    error_message = "At least one admin IP must be specified for SSH access."
  }

  validation {
    condition     = length(var.admin_ip_whitelist) <= 5
    error_message = "Maximum 5 admin IPs supported (OVH IP Firewall has a 20-rule limit)."
  }
}

/*
-----------------------------------------------------------------------------
Keycloak Configuration (injected by GitHub Actions)
Used by the Helm chart to configure the Keycloak admin account and ingress.
-----------------------------------------------------------------------------
*/

variable keycloak_admin_user {
  type = string
}

variable keycloak_admin_password {
  type = string
}

variable keycloak_hostname {
  type = string
}

variable kubernetes_region {
  type = string
}