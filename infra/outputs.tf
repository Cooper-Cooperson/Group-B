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
/*
output "server_public_ipv4" {
  description = "Public IPv4 address of the workplace server"
  value       = local.public_ipv4
}
*/
/*
-----------------------------------------------------------------------------
DNS Nameservers — Point your domain registrar to these
Only relevant if the domain was recently transferred to OVHcloud.
-----------------------------------------------------------------------------
*/
/*
output "dns_nameservers" {
  description = "OVHcloud authoritative nameservers for the domain zone"
  value       = data.ovh_domain_zone.main.name_servers
}
*/
/*
-----------------------------------------------------------------------------
Service URLs — Quick reference for all deployed services
-----------------------------------------------------------------------------
*/
output "service_urls" {
  description = "HTTPS URLs for each service subdomain"
  value = {
    for subdomain, purpose in var.subdomains :
    purpose => "https://${subdomain}.${var.domain}"
  }
}

/*
-----------------------------------------------------------------------------
DNS Records — Verification output (subdomain → IP mapping)
-----------------------------------------------------------------------------
*/
/*
output "dns_records" {
  description = "DNS A-records created (FQDN → target IP)"
  value = {
    for subdomain, record in ovh_domain_zone_record.services :
    "${subdomain}.${var.domain}" => record.target
  }
}
*/
/*
-----------------------------------------------------------------------------
Firewall Status — Confirm the firewall is active
-----------------------------------------------------------------------------
*/
output "firewall_enabled" {
  description = "Whether the OVH IP Firewall is enabled on the server IP"
  value       = ovh_ip_firewall.server.enabled
}

/*
-----------------------------------------------------------------------------
SSH Connection — Copy-paste ready command for admin access
-----------------------------------------------------------------------------
*/
/*
output "ssh_command" {
  description = "SSH connection command (assumes Ubuntu default user)"
  value       = "ssh ubuntu@${local.public_ipv4}"
}
*/
/*
-----------------------------------------------------------------------------
Instance Metadata
-----------------------------------------------------------------------------
*/
/*
output "instance_id" {
  description = "OVH Cloud instance ID"
  value       = ovh_cloud_project_instance.server.id
}

output "instance_region" {
  description = "Datacenter region where the instance is deployed"
  value       = var.region
}
*/