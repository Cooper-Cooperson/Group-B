terraform {
  backend "swift" {
    container         = "terraform-state"
    archive_container = "terraform-state"
    region            = "EU-WEST-PAR" 
    auth_url          = "https://auth.cloud.ovh.net/v3"
  }
}
