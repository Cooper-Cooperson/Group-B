terraform {
  backend "s3" {
    bucket         = "terraform-state-group-b"
    region         = "de1" 
    key            = "keycloak/terraform.tfstate"
    endpoints = {s3 = "https://s3.de1.cloud.ovh.net"}
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}
