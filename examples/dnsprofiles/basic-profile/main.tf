# Basic DNS Security Profile
#
# This example creates a DNS Security profile with domain allow and block lists.
#
# What it creates:
#   - A DNS profile with allowed domains (bypass DNS filtering)
#   - Block list entries for known-bad domains
#   - Traffic logging enabled for all DNS queries
#
# Prerequisites:
#   - Netskope tenant with DNS Security licensed
#   - REST API v2 access enabled
#
# See: https://docs.netskope.com/en/dns-security/

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.6"
    }
  }
}

provider "netskope" {
  # Configure via environment variables:
  # NETSKOPE_SERVER_URL = "https://your-tenant.goskope.com/api/v2"
  # NETSKOPE_API_KEY    = "your-api-token"
}

# =============================================================================
# DNS PROFILE
# =============================================================================

resource "netskope_dns_profile_v2" "basic" {
  name        = "Basic DNS Profile"
  description = "Example profile with domain allow and block lists"
  log_traffic = "All DNS"

  domain_config = {
    # Allow list: domains that bypass DNS security filtering.
    # Use this for trusted internal or partner domains that should never be blocked.
    allow_list = [
      {
        domain_names = ["internal.company.com", "partner.example.com"]
        record_types = ["A", "AAAA"]
      }
    ]

    # Block list: domains that are always blocked regardless of category.
    # Use this for known-bad domains or domains that violate policy.
    block_list = [
      {
        domain_names = ["malware.example.com", "phishing.example.com"]
        record_types = ["A", "AAAA"]
      }
    ]
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# List all DNS profiles to verify creation
data "netskope_dns_profile_v2_list" "all" {
  depends_on = [netskope_dns_profile_v2.basic]
}

# Look up the profile we just created by ID
data "netskope_dns_profile_v2" "lookup" {
  profile_id = netskope_dns_profile_v2.basic.profile_id
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "profile_id" {
  description = "ID of the created DNS profile"
  value       = netskope_dns_profile_v2.basic.profile_id
}

output "profile_name" {
  description = "Name of the created DNS profile"
  value       = netskope_dns_profile_v2.basic.name
}

output "total_profiles" {
  description = "Total number of DNS profiles in the tenant"
  value       = data.netskope_dns_profile_v2_list.all.total
}