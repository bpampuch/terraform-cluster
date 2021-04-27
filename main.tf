# Podstawowa konfiguracja providera
terraform {
  required_version = ">= 0.14.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.35.0"
    }
  }

  backend "local" {
    path = "state/terraform.tfstate" 
  } 
}

provider "openstack" {
   user_name        = "${var.open_stack_user_name}"
   tenant_name      = "${var.open_stack_project_name}"
   password         = "${var.open_stack_password}"
   auth_url         = "${var.open_stack_auth_url}"
   region           = "${var.open_stack_region}"
   user_domain_name = "${var.open_stack_user_domain_name}"
   use_octavia = "true"
}
