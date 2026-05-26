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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.4"
    }
  }
}

provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

resource "ovh_cloud_project_kube" "cluster" {
  service_name = var.ovh_project_id
  name         = "mks-keycloak"
  region       = var.region
}

resource "ovh_cloud_project_kube_nodepool" "pool" {
  service_name  = ovh_cloud_project_kube.cluster.service_name
  kube_id       = ovh_cloud_project_kube.cluster.id
  name          = "pool1"
  flavor_name   = "b3-8"
  desired_nodes = 3
}

# Kubernetes and helm need to be here for Kubernetes refrences.
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

  # Optional: OVH-specific LB annotations
}

# Cert manager
resource "helm_release" "cert_manager" {
  name       = "ovh-cert-lab"
  namespace  = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.6.1"

  set {
    name  = "replicaCount"
    value = "1"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "false"
  }

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Keycloak
resource "helm_release" "keycloak" {
  name       = "keycloak"
  namespace  = "keycloak"
  create_namespace = true

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "keycloak"
  version    = "22.3.0"

  depends_on = [helm_release.ingress_nginx, helm_release.cert_manager]

  set {
    name  = "auth.adminUser"
    value = var.keycloak_admin_user
  }

  set {
    name  = "auth.adminPassword"
    value = var.keycloak_admin_password
  }

  # Enable ingress with TLS
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.hostname"
    value = var.keycloak_hostname
  }

  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress.class"
    value = "nginx"
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

provider "keycloak" {
  url      = "https://${var.keycloak_hostname}/"
  realm    = "master"
  client_id = "admin"
  username  = var.keycloak_admin_user
  password  = var.keycloak_admin_password_for_provider
}

resource "keycloak_realm" "apps" {
  realm        = "apps"
  enabled      = true
  display_name = "Apps Realm"
}

resource "keycloak_openid_client" "my_app" {
  realm_id  = keycloak_realm.apps.id
  client_id = "my-app"

  name                 = "My App"
  enabled              = true
  access_type          = "CONFIDENTIAL"
  standard_flow_enabled = true
  implicit_flow_enabled = false
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://app.example.com/*",
  ]

  web_origins = [
    "https://app.example.com",
  ]

  # Optional: fine‑grained settings (PKCE, logout URLs, etc.)
}

resource "keycloak_openid_client" "kube" {
  realm_id  = keycloak_realm.apps.id
  client_id = user
  name      = "Kubernetes API"
  access_type = "PUBLIC"

  standard_flow_enabled = true
  direct_access_grants_enabled = false

  valid_redirect_uris = ["*"]
}

# Open ID connect (OIDC)
resource "ovh_cloud_project_kube_oidc" "keycloak_oidc" {
  service_name = ovh_cloud_project_kube.cluster.service_name
  kube_id      = ovh_cloud_project_kube.cluster.id

  client_id    = user
  issuer_url = "https://${var.keycloak_hostname}/realms/${keycloak_realm.apps.realm}"

  oidc_username_claim = "preferred_username"
  oidc_username_prefix = "keycloak:"
  oidc_groups_claim    = ["groups"]
  oidc_groups_prefix   = "keycloak:"

  # Optional: CA if you use a custom CA instead of public certs
  # oidc_ca_content = filebase64("ca.pem")
}