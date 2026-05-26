terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

provider "keycloak" {
  url       = var.keycloak_url
  realm     = "master"
  client_id = "admin-cli"
  username  = var.keycloak_admin_user
  password  = var.keycloak_admin_password
}

resource "keycloak_realm" "apps" {
  realm        = "apps"
  enabled      = true
  display_name = "Apps Realm"
}

resource "keycloak_openid_client" "my_app" {
  realm_id  = keycloak_realm.apps.id
  client_id = "my-app"

  name                  = "My App"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  valid_redirect_uris = [
    "https://app.example.com/*"
  ]

  web_origins = [
    "https://app.example.com"
  ]
}

resource "keycloak_openid_client" "kube" {
  realm_id  = keycloak_realm.apps.id
  client_id = "user"
  name      = "Kubernetes API"
  access_type = "PUBLIC"

  standard_flow_enabled = true
  valid_redirect_uris   = ["*"]
}
