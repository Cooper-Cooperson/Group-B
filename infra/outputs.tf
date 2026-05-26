<<<<<<< HEAD
/* ============================================================================= */
/* Escaping Microsoft — Outputs */
/* ============================================================================= */
/* Displays critical infrastructure values after `terraform apply`. */
/* These are needed for: */
/*   • Docker Compose .env configuration (server IP, domain) */
/*   • Domain registrar nameserver delegation */
/*   • SSH access to the server */
/*   • CI/CD pipeline verification */
/* ============================================================================= */

/* ----------------------------------------------------------------------------- */
/* Server Public IP — The single most important output */
/* Used by DNS records, SSH access, and Docker Compose configuration. */
/* ----------------------------------------------------------------------------- */
=======
/*
=============================================================================
Escaping Microsoft — Outputs
=============================================================================
Displays critical infrastructure values after `terraform apply`.
These are needed for:
• Docker Compose .env configuration (server IP, domain)
• Domain registrar nameserver delegation
• SSH access to the server
• CI/CD pipeline verification
=============================================================================
*/

/*
-----------------------------------------------------------------------------
Server Public IP — The single most important output
Used by DNS records, SSH access, and Docker Compose configuration.
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "server_public_ipv4" {
  description = "Public IPv4 address of the workplace server"
  value       = local.public_ipv4
}

<<<<<<< HEAD
/* ----------------------------------------------------------------------------- */
/* DNS Nameservers — Point your domain registrar to these */
/* Only relevant if the domain was recently transferred to OVHcloud. */
/* ----------------------------------------------------------------------------- */
=======
/*
-----------------------------------------------------------------------------
DNS Nameservers — Point your domain registrar to these
Only relevant if the domain was recently transferred to OVHcloud.
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "dns_nameservers" {
  description = "OVHcloud authoritative nameservers for the domain zone"
  value       = data.ovh_domain_zone.main.name_servers
}

<<<<<<< HEAD
/* ----------------------------------------------------------------------------- */
/* Service URLs — Quick reference for all deployed services */
/* ----------------------------------------------------------------------------- */
=======
/*
-----------------------------------------------------------------------------
Service URLs — Quick reference for all deployed services
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "service_urls" {
  description = "HTTPS URLs for each service subdomain"
  value = {
    for subdomain, purpose in var.subdomains :
    purpose => "https://${subdomain}.${var.domain}"
  }
}

<<<<<<< HEAD
/* ----------------------------------------------------------------------------- */
/* DNS Records — Verification output (subdomain → IP mapping) */
/* ----------------------------------------------------------------------------- */
=======
/*
-----------------------------------------------------------------------------
DNS Records — Verification output (subdomain → IP mapping)
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "dns_records" {
  description = "DNS A-records created (FQDN → target IP)"
  value = {
    for subdomain, record in ovh_domain_zone_record.services :
    "${subdomain}.${var.domain}" => record.target
  }
}

<<<<<<< HEAD
/* ----------------------------------------------------------------------------- */
/* Firewall Status — Confirm the firewall is active */
/* ----------------------------------------------------------------------------- */
=======
/*
-----------------------------------------------------------------------------
Firewall Status — Confirm the firewall is active
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "firewall_enabled" {
  description = "Whether the OVH IP Firewall is enabled on the server IP"
  value       = ovh_ip_firewall.server.enabled
}

<<<<<<< HEAD
/* ----------------------------------------------------------------------------- */
/* SSH Connection — Copy-paste ready command for admin access */
/* ----------------------------------------------------------------------------- */
=======
/*
-----------------------------------------------------------------------------
SSH Connection — Copy-paste ready command for admin access
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "ssh_command" {
  description = "SSH connection command (assumes Ubuntu default user)"
  value       = "ssh ubuntu@${local.public_ipv4}"
}

<<<<<<< HEAD
/* ----------------------------------------------------------------------------- */
/* Instance Metadata */
/* ----------------------------------------------------------------------------- */
=======
/*
-----------------------------------------------------------------------------
Instance Metadata
-----------------------------------------------------------------------------
*/
>>>>>>> f52e4e97c53cb7cca03779f903e2cdb1cc3e0a6f
output "instance_id" {
  description = "OVH Cloud instance ID"
  value       = ovh_cloud_project_instance.server.id
}

output "instance_region" {
  description = "Datacenter region where the instance is deployed"
  value       = var.region
}
