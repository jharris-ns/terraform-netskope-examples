# Complete DNS Security Deployment
#
# This example demonstrates a full DNS Security setup including:
#   - DNS profile with domain allow/block lists
#   - Security category enforcement with sinkholing
#   - DNS tunneling detection
#   - Custom DNS server configuration
#   - Inheritance group assignment
#   - Data sources for listing and looking up profiles
#
# Prerequisites:
#   - Netskope tenant with DNS Security licensed
#   - REST API v2 access enabled
#   - Inheritance group names must match existing groups in your tenant
#     (or remove the inheritance_groups block)
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
# VARIABLES
# =============================================================================

variable "profile_name" {
  description = "Name for the DNS security profile"
  type        = string
  default     = "Full DNS Security Profile"
}

variable "sinkhole_ip" {
  description = "IP address for sinkholed domains (use an internal block page or non-routable IP)"
  type        = string
  default     = "198.51.100.1"
}

variable "custom_dns_servers" {
  description = "Custom DNS server IPs (used when custom DNS is enabled)"
  type        = list(string)
  default     = ["10.0.0.53", "10.0.1.53"]
}

variable "inheritance_group" {
  description = "Inheritance group name to assign this profile to (must exist in tenant, set to null to skip)"
  type        = string
  default     = null
}

# =============================================================================
# DNS PROFILE — FULL CONFIGURATION
# =============================================================================

resource "netskope_dns_profile_v2" "full" {
  name        = var.profile_name
  description = "Complete DNS security profile with all configuration options"
  log_traffic = "All DNS"

  # ---------------------------------------------------------------------------
  # Domain Configuration
  # ---------------------------------------------------------------------------
  domain_config = {
    # Security categories — Netskope threat intelligence classification
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
      },
      {
        name   = "Botnet"
        action = "Block"
      }
    ]

    sinkhole_ip = var.sinkhole_ip

    # Allow list — trusted domains that bypass all DNS filtering
    allow_list = [
      {
        domain_names = ["internal.company.com", "vpn.company.com"]
        record_types = ["A", "AAAA"]
      },
      {
        domain_names = ["partner-api.example.com"]
        record_types = ["A"]
      }
    ]

    # Block list — always-blocked domains (overrides everything except allow list)
    block_list = [
      {
        domain_names = ["blocked.example.com", "forbidden.example.com"]
        record_types = ["A", "AAAA"]
      }
    ]

    # When true, blocks ALL domains except those on the allow list.
    # Use with caution — this is a very restrictive mode.
    block_all_except_allow_list = false
  }

  # ---------------------------------------------------------------------------
  # DNS Tunneling Detection
  # ---------------------------------------------------------------------------
  # DNS tunneling is a technique that encodes data in DNS queries to exfiltrate
  # information or establish covert channels. Enable this to detect and block
  # tunneling attempts.
  tunnel_config = {
    enable = true

    # Allow list for tunneling detection — domains here are excluded from
    # tunneling analysis. Use for legitimate services that generate high-volume
    # or unusual DNS patterns (e.g., CDN providers, SaaS apps).
    allow_list = ["cdn.example.com", "saas-app.example.com"]
  }

  # ---------------------------------------------------------------------------
  # Custom DNS Server Configuration
  # ---------------------------------------------------------------------------
  # Route DNS queries through your own DNS servers instead of (or in addition to)
  # Netskope's DNS infrastructure.
  custom_config = {
    enable = true

    # Your internal DNS server IPs
    server_ip = var.custom_dns_servers

    # When true, bypasses the original DNS server configured on the endpoint
    bypass_original_dns = true

    # When true, falls back to Netskope DNS if custom servers are unreachable
    fallback_to_netskope_dns = true
  }

  # ---------------------------------------------------------------------------
  # Inheritance Group Assignment
  # ---------------------------------------------------------------------------
  # Assign this profile to an inheritance group for organizational policy management.
  # The group must already exist in your tenant. Max 1 group per profile.
  inheritance_groups = var.inheritance_group != null ? [var.inheritance_group] : []
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# List all DNS profiles
data "netskope_dns_profile_v2_list" "all" {
  depends_on = [netskope_dns_profile_v2.full]
}

# Look up the profile we created
data "netskope_dns_profile_v2" "lookup" {
  profile_id = netskope_dns_profile_v2.full.profile_id
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "profile_id" {
  description = "ID of the full DNS security profile"
  value       = netskope_dns_profile_v2.full.profile_id
}

output "profile_name" {
  description = "Name of the DNS security profile"
  value       = netskope_dns_profile_v2.full.name
}

output "tunnel_detection_enabled" {
  description = "Whether DNS tunneling detection is enabled"
  value       = data.netskope_dns_profile_v2.lookup.tunnel_config.enable
}

output "custom_dns_enabled" {
  description = "Whether custom DNS servers are configured"
  value       = data.netskope_dns_profile_v2.lookup.custom_config.enable
}

output "custom_dns_servers" {
  description = "Custom DNS server IPs"
  value       = data.netskope_dns_profile_v2.lookup.custom_config.server_ip
}

output "total_profiles" {
  description = "Total number of DNS profiles in the tenant"
  value       = data.netskope_dns_profile_v2_list.all.total
}