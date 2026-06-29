# AI Gateway Full Setup Example
#
# End-to-end AIG configuration that wires all resources together in dependency
# order:
#
#   1. Token group + token  — credential identity for AI applications
#   2. AI provider          — custom LLM backend
#   3. MCP server           — agent tool/resource server
#   4. Rate limit           — per-group throughput control
#   5. Appliance            — on-premise proxy gateway
#   6. Enrollment token     — one-time token to register the appliance
#
# Use this as a starting point for a production AIG deployment. Replace
# hostnames and names with values appropriate for your environment.
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

# --- Token group and tokens ---

resource "netskope_aig_token_group" "it_dept" {
  name        = "IT Department"
  description = "API tokens for IT department AI tools"
}

resource "netskope_aig_token" "it_bot" {
  name           = "it-bot-key"
  token_group_id = netskope_aig_token_group.it_dept.id

  expire_in = {
    unit  = "month"
    value = 3
  }
}

# --- AI provider ---

resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

# --- MCP server ---

resource "netskope_aig_mcp_server" "github" {
  name     = "mcp-cust-github"
  host     = "api.githubcopilot.com"
  port     = 443
  path     = "/mcp"
  protocol = "https-system"
}

# --- Rate limits ---

resource "netskope_aig_rate_limit" "it_ai" {
  name = "it-ai-limit"

  criteria = {
    apply_on        = "ai"
    ai_provider_ids = [netskope_aig_ai_provider.ollama.id]
    token_group_ids = [netskope_aig_token_group.it_dept.id]
  }

  limit = {
    requests = 1000
    unit     = "hour"
  }
}

# --- Appliance ---

resource "netskope_aig_appliance" "hq" {
  name = "hq-aig-01"
  host = "aig-hq.internal.company.com"

  ai_provider_ids = [netskope_aig_ai_provider.ollama.id]
  mcp_server_ids  = [netskope_aig_mcp_server.github.id]

  ports = {
    http  = { enable = false, port = 80 }
    https = { enable = true, port = 443 }
  }
}

resource "netskope_aig_appliance_enrollment_token" "hq" {
  appliance_id = netskope_aig_appliance.hq.id
}

# --- Outputs ---

output "appliance_id" {
  value = netskope_aig_appliance.hq.id
}

output "enrollment_token" {
  value     = netskope_aig_appliance_enrollment_token.hq.enrollment_token
  sensitive = true
}