# AI Gateway Appliance Example
#
# Creates an AIG appliance — the on-premise proxy gateway that sits between
# AI applications and backend AI providers / MCP servers.
#
# After Terraform creates the appliance, it must be registered by running the
# enrollment token flow (see enrollment-token example) and installing the
# appliance software on the target host.
#
# ai_provider_ids and mcp_server_ids assign backends to this appliance.
# The appliance will only proxy traffic for associated providers/servers.
#
# See: https://docs.netskope.com/en/netskope-ai-gateway/

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = "~> 0.4.6"
    }
  }
}

provider "netskope" {
  # Configure via environment variables:
  # NETSKOPE_SERVER_URL = "https://your-tenant.goskope.com/api/v2"
  # NETSKOPE_API_KEY    = "your-api-token"
}

resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

resource "netskope_aig_appliance" "hq" {
  name = "hq-aig-01"
  host = "aig-hq.internal.company.com"

  ai_provider_ids = [netskope_aig_ai_provider.ollama.id]

  ports = {
    http = {
      enable = false
      port   = 80
    }
    https = {
      enable = true
      port   = 443
    }
  }
}

output "appliance_id" {
  value = netskope_aig_appliance.hq.id
}

output "appliance_status" {
  value = netskope_aig_appliance.hq.status
}