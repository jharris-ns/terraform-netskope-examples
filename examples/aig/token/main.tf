# AI Gateway Token Example
#
# Creates API tokens that AI applications use to authenticate to the AIG proxy.
# Tokens belong to a token group and carry an expiry.
#
# IMPORTANT: The bearer token string is only available in the create response.
# Terraform does not re-read it on refresh — store the value securely at
# apply time (e.g., pipe output to a secrets manager).
#
# expire_in is required. Valid units: hour, day, week, month, year.
# Maximum value: 8760 hours (1 year).
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

# Long-lived token (1 year)
resource "netskope_aig_token" "long_lived" {
  name           = "IT ChatBot annual key"
  token_group_id = netskope_aig_token_group.it_chatbot.id

  expire_in = {
    unit  = "year"
    value = 1
  }
}

# Token that expires in 24 hours
resource "netskope_aig_token" "short_lived" {
  name           = "IT ChatBot 24h key"
  token_group_id = netskope_aig_token_group.it_chatbot.id

  expire_in = {
    unit  = "hour"
    value = 24
  }
}

output "long_lived_token_id" {
  value = netskope_aig_token.long_lived.id
}

output "short_lived_token_expire_time" {
  value = netskope_aig_token.short_lived.expire_time
}
