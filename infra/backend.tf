terraform {
  backend "s3" {
    bucket         = "terraform-state-group-b"
    region         = "de1" 
    key            = "infra/terraform.tfstate"
    endpoint       = "https://s3.de1.io.cloud.ovh.net"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}
