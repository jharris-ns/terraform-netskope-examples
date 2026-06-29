# AI Gateway Custom AI Provider Example
#
# Registers a custom (on-premise or private) AI backend with the AIG proxy.
# The proxy routes AI requests from authorized applications to these backends.
#
# Resource naming constraints:
#   - Name must start with "cust-"
#   - Maximum 15 characters total
#
# Supported protocols: https-system (public CA), https-custom (uploaded CA),
#                      http (no TLS)
# Supported schemas:   openai
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

# Custom provider using HTTPS with system CA (e.g. public LLM with TLS)
resource "netskope_aig_ai_provider" "ollama" {
  name     = "cust-ollama"
  host     = "ollama.internal.company.com"
  port     = 443
  protocol = "https-system"
  schema   = "openai"
}

# Custom provider that skips TLS verification (dev/test only)
resource "netskope_aig_ai_provider" "dev_backend" {
  name     = "cust-dev-llm"
  host     = "llm-dev.internal.company.com"
  port     = 8080
  protocol = "http"
  schema   = "openai"
}

output "ollama_provider_id" {
  value = netskope_aig_ai_provider.ollama.id
}