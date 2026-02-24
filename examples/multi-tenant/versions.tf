terraform {
  required_version = ">= 1.3"

  required_providers {
    sequin = {
      source  = "registry.terraform.io/clintdigital/sequin"
      version = ">= 0.1"
    }
  }
}

provider "sequin" {
  endpoint = var.sequin_endpoint
  api_key  = var.sequin_api_key
}
