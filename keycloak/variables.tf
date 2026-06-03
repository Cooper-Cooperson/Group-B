variable "domain" {
  description = "Root domain name managed in OVHcloud DNS (e.g., suitit.tech)"
  type        = string
}

variable keycloak_admin_user {
  type = string
}

variable keycloak_admin_password {
  type = string
}

variable keycloak_hostname {
  type = string
}

variable keycloak_version {
  type = string
}

variable ssh_key_name_keycloack {
  description = "Name of the SSH key pair already registered in the OVHcloud project"
  type        = string
}

variable "instance_flavor" {
  description = "OVHcloud instance flavor ID (e.g., b2-15, b2-30, b2-60)"
  type        = string
  default     = "1feb4dbd-5cad-4315-8721-44deaf685f41"
}

variable "instance_image" {
  description = "OS image  UUID (Ubuntu recommended for Docker Compose)"
  type        = string
  default     = "d8ed87d0-1944-4f20-9108-cf21028ab9ba"
}

variable "ovh_project_id" {
  description = "OVH Public Cloud project ID (GitHub secret: OVH_PROJECT_ID)"
  type        = string
}

variable "region" {
  type        = string
}

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