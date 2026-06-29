# AI Gateway Token Group Example
#
# Creates a token group — a logical container for API tokens issued to
# AI-powered applications. Token groups are required before creating tokens.
#
# Use case: Organize tokens by application or department (e.g., one group
# per chatbot, one per team) so usage and rate limits can be tracked separately.
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
  description = "Tokens for the IT department ChatBot application"
}

output "token_group_id" {
  value = netskope_aig_token_group.it_chatbot.id
}