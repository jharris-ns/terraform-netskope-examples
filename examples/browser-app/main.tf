# Browser-Based Private Application Example
#
# This example demonstrates how to create a browser-accessible private application
# that users can access through the Netskope web portal without requiring the NPA client.
#
# Use case: Internal web applications like wikis, dashboards, or admin panels
# that should be accessible via browser from anywhere.
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. real_host MUST be a FQDN (not an IP address) for HTTPS applications
#    WRONG: real_host = "192.168.10.50"
#    RIGHT: real_host = "wiki.internal.local"
#
# 2. is_user_portal_app = true may not be allowed on all Netskope tenants
#    If you get "User Portal App cannot be created" error, set this to false
#    or use client-app example instead
#
# 3. This example requires at least one publisher to exist in your tenant
#    Run publisher-management example first if you don't have publishers
#
# 4. Browser/clientless apps do not support multiple ports or port ranges
#    Only a single TCP port can be specified per browser-accessible app.
#    Error: "Clientless private app doesn't support port range and multiple port"
#
# See: https://docs.netskope.com/en/configure-browser-access-for-private-apps/
#
# =============================================================================

terraform {
  required_providers {
    netskope = {
      source = "netskopeoss/netskope"
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

variable "publisher_name" {
  description = "Name of the publisher to use (must exist in your tenant)"
  type        = string
  default     = null # Set to null to use the first available publisher
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Look up existing publishers to assign to the app
data "netskope_npa_publishers_list" "all" {}

# Find the publisher by name, or use the first one if no name specified
locals {
  # Pattern: Conditional publisher selection
  #
  # This demonstrates two common Terraform patterns:
  #
  # 1. Ternary operator (condition ? true_value : false_value)
  #    - If var.publisher_name is set, search for that specific publisher
  #    - If null, fall back to the first available publisher
  #
  # 2. For-expression filtering: [for item in list : item if condition]
  #    - Iterates through all publishers
  #    - Returns only those matching the name
  #    - [0] gets the first (and should be only) match
  #
  # Result: A single publisher object with .publisher_id and .publisher_name
  #
  publisher = var.publisher_name != null ? (
    [for p in data.netskope_npa_publishers_list.all.data.publishers : p if p.publisher_name == var.publisher_name][0]
  ) : data.netskope_npa_publishers_list.all.data.publishers[0]
}

# Create a browser-accessible private application
resource "netskope_npa_private_app" "internal_wiki" {
  private_app_name     = "Internal Wiki"
  private_app_hostname = "wiki.internal.company.com"
  private_app_protocol = "https"

  # IMPORTANT: real_host must be a FQDN, not an IP address, for HTTPS apps
  # The API will reject IP addresses with: "Enter a FQDN. x.x.x.x is not a valid host"
  real_host = "wiki.internal.local"

  # Enable browser/clientless access
  clientless_access = true

  # NOTE: is_user_portal_app may not be allowed on all tenants
  # If you get "User Portal App cannot be created", set this to false
  is_user_portal_app = true

  # Protocol configuration for HTTPS
  # Note: If adding multiple protocols, list them in ascending port order
  # to avoid Terraform drift (e.g., 80, 443). The API may return protocols
  # in a different order, causing plan changes if not sorted.
  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  # Assign to publisher - uses publisher_name variable if set, otherwise first available
  publishers = [
    {
      publisher_id   = tostring(local.publisher.publisher_id)
      publisher_name = local.publisher.publisher_name
    }
  ]

  # Security settings
  trust_self_signed_certs = false
  use_publisher_dns       = true
}

# Output the application details
output "app_name" {
  description = "Name of the created private application"
  value       = netskope_npa_private_app.internal_wiki.private_app_name
}

output "app_hostname" {
  description = "Hostname of the created private application"
  value       = netskope_npa_private_app.internal_wiki.private_app_hostname
}

output "publisher_used" {
  description = "Publisher assigned to this application"
  value       = local.publisher.publisher_name
}
