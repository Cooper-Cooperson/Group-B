/* ============================================================================= */
/* Escaping Microsoft — Input Variables */
/* ============================================================================= */
/* These variables are injected by GitHub Actions via TF_VAR_<name> environment */
/* variables, sourced from repository secrets in Cooper-Cooperson/Group-B. */
/* */
/* CI/CD Mapping: */
/*   GitHub Secret          → TF_VAR_                → Terraform Variable */
/*   APPLICATION_KEY        → TF_VAR_application_key        → var.application_key */
/*   APPLICATION_SECRET     → TF_VAR_application_secret     → var.application_secret */
/*   CONSUMER_KEY           → TF_VAR_consumer_key           → var.consumer_key */
/*   ENDPOINT               → TF_VAR_endpoint               → var.endpoint */
/*   OVH_PROJECT_ID         → TF_VAR_ovh_project_id         → var.ovh_project_id */
/*   REGION                 → TF_VAR_region                  → var.region */
/* ============================================================================= */

/* ----------------------------------------------------------------------------- */
/* OVH API Credentials (injected by GitHub Actions) */
/* These authenticate Terraform against the OVH API for DNS and firewall mgmt. */
/* Generate at: https://api.ovh.com/createToken/ */
/* ----------------------------------------------------------------------------- */
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

/* ----------------------------------------------------------------------------- */
/* OVH Public Cloud Project (injected by GitHub Actions) */
/* ----------------------------------------------------------------------------- */
variable "ovh_project_id" {
  description = "OVH Public Cloud project ID (GitHub secret: OVH_PROJECT_ID)"
  type        = string
}

variable "region" {
  description = "OVHcloud datacenter region, e.g. GRA11, SBG5, DE1 (GitHub secret: REGION)"
  type        = string
  default     = "GRA11"
}

/* ----------------------------------------------------------------------------- */
/* Compute Instance Configuration */
/* These can be set as additional GitHub secrets or have sensible defaults. */
/* Sizing for 50-100 users running the full open-source stack: */
/*   b2-30  (8 vCPU, 30 GB RAM)  — recommended for production */
/*   b2-15  (4 vCPU, 15 GB RAM)  — minimum viable option */
/* ----------------------------------------------------------------------------- */
variable "instance_name" {
  description = "Hostname for the compute instance"
  type        = string
  default     = "escaping-microsoft-srv"
}

variable "instance_flavor" {
  description = "OVHcloud instance flavor ID (e.g., b2-15, b2-30, b2-60)"
  type        = string
  default     = "b2-30"
}

variable "instance_image" {
  description = "OS image name or ID (Ubuntu recommended for Docker Compose)"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "ssh_keypair_name" {
  description = "Name of the SSH key pair already registered in your OVHcloud project"
  type        = string
}

/* ----------------------------------------------------------------------------- */
/* DNS / Domain Configuration */
/* The root domain must already be registered and managed via OVHcloud DNS. */
/* Set as a GitHub secret or TF_VAR_domain in your workflow. */
/* ----------------------------------------------------------------------------- */
variable "domain" {
  description = "Root domain name managed in OVHcloud DNS (e.g., suitit.nl)"
  type        = string
}

variable "dns_ttl" {
  description = "TTL (in seconds) for DNS A-records. Lower to 300 during initial testing."
  type        = number
  default     = 3600
}

/* Service subdomains — add new services here (one-line change) */
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

/* ----------------------------------------------------------------------------- */
/* Firewall — Admin SSH Access Whitelist */
/* IMPORTANT: Restrict SSH to known admin IPs only (principle of least privilege). */
/* Max 5 entries — the OVH IP Firewall supports 20 rules total; 5 are reserved */
/* for SSH and the rest for service ports. */
/* Set as TF_VAR_admin_ip_whitelist='["x.x.x.x/32"]' in your GitHub workflow. */
/* ----------------------------------------------------------------------------- */
variable "admin_ip_whitelist" {
  description = <<-EOT
    List of CIDR blocks allowed SSH access (port 22).
    Example: ["203.0.113.10/32", "198.51.100.0/24"]
    WARNING: Never set this to ["0.0.0.0/0"] in production!
  EOT
  type        = list(string)

  validation {
    condition     = length(var.admin_ip_whitelist) > 0
    error_message = "At least one admin IP must be specified for SSH access."
  }

  validation {
    condition     = length(var.admin_ip_whitelist) <= 5
    error_message = "Maximum 5 admin IPs supported (OVH IP Firewall has a 20-rule limit)."
  }
}
