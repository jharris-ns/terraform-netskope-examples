# Client-Based Private Application Example
#
# This example demonstrates how to create a private application that requires
# the Netskope NPA client for access. Ideal for non-HTTP protocols like SSH, RDP,
# or native desktop applications.
#
# Use case: SSH access to servers, RDP to Windows machines, database connections
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. clientless_access MUST be set to true for non-HTTP protocols (SSH, RDP, TCP)
#    Despite the name, this is REQUIRED for these protocols to work.
#    If false, you'll get: "Clientless_access need to be set for non-web browser access"
#    See: https://docs.netskope.com/en/configure-browser-access-for-private-apps/
#
# 2. real_host should be a FQDN for consistency, though IPs may work for non-HTTPS
#    Best practice: Always use FQDNs like "server.internal.local"
#
# 3. This example requires at least one publisher to exist in your tenant
#    Run publisher-management example first if you don't have publishers
#
# 4. Protocol Ordering (Issue #14 - causes Terraform plan drift)
#    If defining multiple protocols for an app, list them in this exact order:
#    - TCP protocols first, sorted by port ascending (22, 80, 443)
#    - UDP protocols second, sorted by port ascending (53, 123)
#    The API returns protocols in sorted order; mismatched ordering causes drift.
#
# =============================================================================

terraform {
  required_providers {
    netskope = {
      source = "netskopeoss/netskope"
    }
  }
}

provider "netskope" {}

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

# Look up existing publishers
data "netskope_npa_publishers_list" "all" {}

# Find the publisher by name, or use the first one if no name specified
locals {
  # Pattern: Conditional publisher selection with for-expression filtering
  #
  # How it works:
  # 1. If var.publisher_name is provided (not null):
  #    - Filter publishers list to find matching name
  #    - [0] extracts the first match from the filtered list
  # 2. If var.publisher_name is null:
  #    - Simply use the first publisher in the list
  #
  # The result is a publisher object you can reference as:
  #   local.publisher.publisher_id
  #   local.publisher.publisher_name
  #
  publisher = var.publisher_name != null ? (
    [for p in data.netskope_npa_publishers_list.all.data.publishers : p if p.publisher_name == var.publisher_name][0]
  ) : data.netskope_npa_publishers_list.all.data.publishers[0]
}

# Example 1: SSH Server Access
resource "netskope_npa_private_app" "ssh_bastion" {
  private_app_name     = "SSH Bastion Host"
  private_app_hostname = "bastion.internal.company.com"
  private_app_protocol = "ssh"
  real_host            = "bastion.internal.local"

  # IMPORTANT: clientless_access MUST be true for non-HTTP protocols
  # Without this, you'll get: "Clientless_access need to be set for non-web browser access"
  clientless_access  = true
  is_user_portal_app = false

  # SSH protocol on port 22
  # Note: If adding multiple protocols, list them in ascending port order
  # to avoid Terraform drift (e.g., 22, 80, 443). The API may return protocols
  # in a different order, causing plan changes if not sorted.
  protocols = [
    {
      port     = "22"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(local.publisher.publisher_id)
      publisher_name = local.publisher.publisher_name
    }
  ]

  use_publisher_dns = true
}

# Example 2: RDP Access to Windows Server
resource "netskope_npa_private_app" "rdp_server" {
  private_app_name     = "Windows Admin Server"
  private_app_hostname = "admin-win.internal.company.com"
  private_app_protocol = "rdp"
  real_host            = "admin-win.internal.local"

  # IMPORTANT: clientless_access MUST be true for RDP
  clientless_access  = true
  is_user_portal_app = false

  # RDP protocol on port 3389
  # Note: If adding multiple protocols, list them in ascending port order
  # to avoid Terraform drift (e.g., 22, 3389).
  protocols = [
    {
      port     = "3389"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(local.publisher.publisher_id)
      publisher_name = local.publisher.publisher_name
    }
  ]

  use_publisher_dns = true
}

# Example 3: Database Server (TCP)
resource "netskope_npa_private_app" "database_cluster" {
  private_app_name     = "PostgreSQL Database"
  private_app_hostname = "postgres.internal.company.com"
  private_app_protocol = "tcp"
  real_host            = "postgres.internal.local"

  # IMPORTANT: clientless_access MUST be true for TCP protocol apps
  clientless_access  = true
  is_user_portal_app = false

  # PostgreSQL default port
  # Note: If adding multiple protocols, list them in ascending port order
  # to avoid Terraform drift.
  protocols = [
    {
      port     = "5432"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(local.publisher.publisher_id)
      publisher_name = local.publisher.publisher_name
    }
  ]

  use_publisher_dns = true
}

# Outputs
output "ssh_app_hostname" {
  description = "Hostname for SSH access via NPA client"
  value       = netskope_npa_private_app.ssh_bastion.private_app_hostname
}

output "rdp_app_hostname" {
  description = "Hostname for RDP access via NPA client"
  value       = netskope_npa_private_app.rdp_server.private_app_hostname
}

output "database_app_hostname" {
  description = "Hostname for database access via NPA client"
  value       = netskope_npa_private_app.database_cluster.private_app_hostname
}

output "publisher_used" {
  description = "Publisher assigned to these applications"
  value       = local.publisher.publisher_name
}
