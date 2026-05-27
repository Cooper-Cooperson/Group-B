terraform {
  backend "swift" {
    container         = "terraform-state"
    archive_container = "terraform-state"
    region            = "DE1" 
    auth_url          = "https://auth.cloud.ovh.net/v3"
  }
}
