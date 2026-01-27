terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.4"
    }
  }
}

provider "netskope" {
  api_key    = var.netskope_api_key
  server_url = var.netskope_server_url
}
