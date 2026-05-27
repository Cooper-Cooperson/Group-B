terraform {
  backend "swift" {
    container         = "terraform-state-group-b"
    archive_container = "terraform-state-group-b"
    region            = "DE1" 
    auth_url          = "https://auth.cloud.ovh.net/v3"
    key               = "infra/terraform.tfstate"
  }
}
