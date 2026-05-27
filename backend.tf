terraform {
  backend "swift" {
    container         = "terraform-state"
    archive_container = "terraform-state"
    region            = "GRA" # or your region
    auth_url          = "https://auth.cloud.ovh.net/v3"
  }
}
