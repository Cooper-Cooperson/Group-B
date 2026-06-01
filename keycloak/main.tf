terraform {
  required_version = ">= 1.6.0"

  required_providers {
    ovh = {
      source = "ovh/ovh"
      version = ">= 2.1.0"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }
}

provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

resource "ovh_cloud_project_network_private" "network" {
  service_name = var.ovh_project_id 
  vlan_id     = 42
  name       = "terraform_testacc_private_net"
  regions    = [var.region]
}

resource "ovh_cloud_project_network_private_subnet" "subnet" {
  service_name = var.ovh_project_id 
  network_id   = ovh_cloud_project_network_private.network.id

  region     = var.region
  start      = "192.168.168.100"
  end        = "192.168.168.200"
  network    = "192.168.168.0/24"
  dhcp       = true
  no_gateway = false
}

resource "ovh_cloud_project_gateway" "gateway" {
  service_name = var.ovh_project_id 
  name       = "gateway"
  model      = "s"
  region     = var.region
  network_id = tolist(ovh_cloud_project_network_private.network.regions_attributes[*].openstackid)[0]
  subnet_id  = ovh_cloud_project_network_private_subnet.subnet.id
}

data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init-keycloak-caddy.yaml.tpl")

  vars = {
    KEYCLOAK_VERSION   = var.keycloak_version
    KEYCLOAK_ADMIN     = var.keycloak_admin_user
    KEYCLOAK_PASSWORD  = var.keycloak_admin_password
  }
}

resource "ovh_cloud_project_instance" "keycloak_vm" {
  service_name = var.ovh_project_id
  region       = var.region
  name         = "keycloak-vm"
  
  flavor {
    flavor_id = "1feb4dbd-5cad-4315-8721-44deaf685f41" #var.instance_flavor
  }

  boot_from {
    image_id = "d8ed87d0-1944-4f20-9108-cf21028ab9ba" #var.instance_image
  }

  ssh_key {
    name = var.ssh_key_name_keycloack
  }
  billing_period = "hourly"
  user_data       = data.template_file.cloud_init.rendered

  network {
    public = true
  }
}