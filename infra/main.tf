# =============================================================================
# Escaping Microsoft — Main Terraform Configuration
# =============================================================================
# Provisions the complete network and security infrastructure on OVHcloud
# for a self-hosted Microsoft 365 replacement (50-100 users).
#
# Resources provisioned:
#   1. Compute instance   (ovh_cloud_project_instance)
#   2. IP Firewall        (ovh_ip_firewall + ovh_ip_firewall_rule)
#   3. DNS A-records      (ovh_domain_zone_record)
#
# CI/CD: Deployed via GitHub Actions (Cooper-Cooperson/Group-B)
#        Secrets injected as TF_VAR_* environment variables.
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform Settings & Provider Requirements
# Using ONLY the official ovh/ovh provider for all resources.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = ">= 2.13.0"
    }
  }
}

# -----------------------------------------------------------------------------
# OVH Provider — Authenticated via GitHub Actions secrets
# Manages: DNS zones, cloud instances, IP firewalls
# Docs: https://registry.terraform.io/providers/ovh/ovh/latest/docs
# -----------------------------------------------------------------------------
provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

resource "ovh_cloud_project_network_private" "mks_net" {
  service_name = var.ovh_project_id
  name         = "mks-private-network"
  vlan_id      = 0
}

resource "ovh_cloud_project_network_private_subnet" "mks_subnet" {
  service_name = var.ovh_project_id
  network_id   = ovh_cloud_project_network_private.mks_net.id

  start = "192.168.10.10"
  end   = "192.168.10.250"
  network = "192.168.10.0/24"
  dhcp    = true
}

resource "ovh_cloud_project_kube" "cluster" {
  service_name = var.ovh_project_id
  name         = "mks-keycloak"
  region       = var.region
  
  private_network_id = ovh_cloud_project_network_private.mks_net.id
  nodes_subnet_id    = ovh_cloud_project_network_private_subnet.mks_subnet.id
}

resource "ovh_cloud_project_kube_nodepool" "pool" {
  service_name  = ovh_cloud_project_kube.cluster.service_name
  kube_id       = ovh_cloud_project_kube.cluster.id
  name          = "pool1"
  flavor_name   = "b3-8"
  desired_nodes = 3
}

provider "kubernetes" {
  host = ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].host

  client_certificate     = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_certificate)
  client_key             = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_key)
  cluster_ca_certificate = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].host

    client_certificate     = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_certificate)
    client_key             = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_key)
    cluster_ca_certificate = base64decode(ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].cluster_ca_certificate)
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "cert_manager" {
  name             = "ovh-cert-lab"
  namespace        = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.6.1"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "keycloak" {
  name             = "keycloak"
  namespace        = "keycloak"
  create_namespace = true

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "keycloak"
  version    = "22.3.0"

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.cert_manager
  ]

  set {
    name  = "auth.adminUser"
    value = var.keycloak_admin_user
  }

  set {
    name  = "auth.adminPassword"
    value = var.keycloak_admin_password
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.hostname"
    value = var.keycloak_hostname
  }

  set {
    name  = "ingress.tls[0].hosts[0]"
    value = var.keycloak_hostname
  }

  set {
    name  = "ingress.tls[0].secretName"
    value = "keycloak-tls"
  }
}