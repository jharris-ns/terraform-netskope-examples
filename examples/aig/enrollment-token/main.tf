# AI Gateway Appliance Enrollment Token Example
#
# Generates a one-time enrollment token used to register a physical or virtual
# AIG appliance with the Netskope tenant.
#
# Workflow:
#   1. Create the appliance resource (or reference an existing one)
#   2. Apply this configuration to generate an enrollment token
#   3. Copy the token output and use it during appliance software installation
#      to register the appliance — the token is consumed on first use
#
# NOTE: The enrollment_token output is sensitive. Store it securely and do not
# log it. It is only available immediately after creation; Terraform cannot
# re-read it on refresh.
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

resource "netskope_aig_appliance" "hq" {
  name = "hq-aig-01"
  host = "aig-hq.internal.company.com"

  ports = {
    http  = { enable = false, port = 80 }
    https = { enable = true, port = 443 }
  }
}

resource "netskope_aig_appliance_enrollment_token" "hq" {
  appliance_id = netskope_aig_appliance.hq.id
}

output "enrollment_token" {
  value     = netskope_aig_appliance_enrollment_token.hq.enrollment_token
  sensitive = true
}

output "token_expires" {
  value = netskope_aig_appliance_enrollment_token.hq.expire_time
}