# AI Gateway Rate Limit Example
#
# Defines request throughput limits per appliance for AI provider or MCP traffic.
# Rate limits can be scoped to specific token groups, AI providers, and models.
#
# The criteria.apply_on field controls which traffic type the rule targets:
#   "ai"  — requests to AI providers (LLMs)
#   "mcp" — requests to MCP servers (agent tools)
#
# Omitting optional criteria fields (ai_provider_ids, token_group_ids, models)
# creates a broad rule that applies to all matching traffic.
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

resource "netskope_aig_token_group" "it_chatbot" {
  name        = "IT ChatBot"
  description = "Tokens for the IT department ChatBot"
}

resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

# AI traffic rate limit: 500 requests/hour for a specific token group and provider
resource "netskope_aig_rate_limit" "corp_gpt" {
  name = "corp-gpt-limit"

  criteria = {
    apply_on = "ai"

    ai_provider_ids = [netskope_aig_ai_provider.ollama.id]

    token_group_ids = [netskope_aig_token_group.it_chatbot.id]

    models = [
      { type = "exact", value = "gpt-4o" },
      { type = "exact", value = "gpt-4o-mini" },
    ]
  }

  limit = {
    requests = 500
    unit     = "hour"
  }

  response = "Rate limit exceeded. Please try again later."
}

# Broad AI rate limit across all providers (no filtering)
resource "netskope_aig_rate_limit" "global_ai" {
  name = "global-ai"

  criteria = {
    apply_on = "ai"
  }

  limit = {
    requests = 10000
    unit     = "day"
  }
}