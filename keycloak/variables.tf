/*
-----------------------------------------------------------------------------
Keycloak Stack — Input Variables
Injected by GitHub Actions via terraform.tfvars
(auto-generated from repository secrets).
The workflow writes ALL secrets into the tfvars file, so variables
that only the infra stack uses are silently ignored here.
-----------------------------------------------------------------------------
*/

variable "endpoint" {
  type = string
}

variable "application_key" {
  type      = string
  sensitive = true
}

variable "application_secret" {
  type      = string
  sensitive = true
}

variable "consumer_key" {
  type      = string
  sensitive = true
}

variable "ovh_project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "GRA11"
}

variable "keycloak_admin_user" {
  type    = string
  default = "admin"
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}

variable "keycloak_hostname" {
  type = string
}

variable "keycloak_url" {
  description = "Full Keycloak URL including protocol (e.g., https://auth.suitit.nl/)"
  type        = string
}

/* ---- Variables written by the shared tfvars but unused by this stack ---- */
/* Terraform silently ignores extra keys in .tfvars, but only if they are    */
/* declared. We declare them here to avoid 'unsupported argument' errors.    */

variable "os_username" {
  type    = string
  default = ""
}

variable "os_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "os_project_name" {
  type    = string
  default = ""
}

variable "os_project_id" {
  type    = string
  default = ""
}

variable "domain" {
  type    = string
  default = ""
}

variable "ssh_keypair_name" {
  type    = string
  default = ""
}

variable "admin_ip_whitelist" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}