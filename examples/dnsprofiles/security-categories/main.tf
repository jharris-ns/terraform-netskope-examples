# DNS Security Profile with Security Categories
#
# This example creates a DNS Security profile that uses security categories
# to block or sinkhole malicious domains, with a custom sinkhole IP.
#
# What it creates:
#   - A DNS profile with security category enforcement
#   - Sinkhole action for malware domains (redirects to a safe IP)
#   - Block action for phishing domains (returns NXDOMAIN)
#   - Domain allow list for false-positive overrides
#
# Security categories vs domain lists:
#   - Security categories use Netskope's threat intelligence to classify domains
#     in real time. You choose the action (Block or Sinkhole) per category.
#   - Domain allow/block lists are static overrides for specific FQDNs.
#   - Allow lists take precedence: a domain on the allow list is never blocked,
#     even if it matches a blocked security category.
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
# DNS PROFILE WITH SECURITY CATEGORIES
# =============================================================================

resource "netskope_dns_profile_v2" "security" {
  name        = "Security Categories Profile"
  description = "DNS profile with category-based blocking and sinkholing"
  log_traffic = "All DNS"

  domain_config = {
    # Security categories use Netskope threat intelligence to classify domains.
    # Action options:
    #   "Block"    — returns NXDOMAIN (domain not found)
    #   "Sinkhole" — redirects to sinkhole_ip below
    security_categories = [
      {
        name   = "Malware"
        action = "Sinkhole"
      },
      {
        name   = "Phishing"
        action = "Block"
      },
      {
        name   = "Command and Control"
        action = "Block"
      }
    ]

    # Sinkhole IP: where sinkholed domains resolve to.
    # Use an internal IP that serves a block page, or a non-routable address.
    sinkhole_ip = "198.51.100.1"

    # Allow list overrides: domains here are never blocked, even if they match
    # a security category above. Use for known false positives.
    allow_list = [
      {
        domain_names = ["legitimate-service.example.com"]
        record_types = ["A", "AAAA"]
      }
    ]
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "profile_id" {
  description = "ID of the security categories DNS profile"
  value       = netskope_dns_profile_v2.security.profile_id
}

output "profile_name" {
  description = "Name of the security categories DNS profile"
  value       = netskope_dns_profile_v2.security.name
}