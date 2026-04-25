# =============================================================================
# Netskope IPSec Tunnel Management with Terraform
# =============================================================================
# This example demonstrates how to create and manage IPSec tunnels for traffic
# steering to Netskope's Security Cloud Platform.
#
# Prerequisites:
# - Netskope tenant with IPSec/GRE license enabled
# - REST API v2 token with appropriate permissions
# - Network device (firewall/router) with public IP for tunnel source
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = "~> 0.3.4"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================
# Option 1: Use environment variables (recommended for security)
#   export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
#   export NETSKOPE_API_KEY="your-api-token"
#
# Option 2: Use variables (shown below)
# =============================================================================

provider "netskope" {
  server_url = var.netskope_server_url
  api_key    = var.netskope_api_key
}

# =============================================================================
# Variables
# =============================================================================

variable "netskope_server_url" {
  description = "Netskope tenant API v2 URL (e.g., https://your-tenant.goskope.com/api/v2)"
  type        = string
  sensitive   = true
}

variable "netskope_api_key" {
  description = "Netskope REST API v2 token"
  type        = string
  sensitive   = true
}

variable "tunnel_name" {
  description = "Site name for the IPSec tunnel"
  type        = string
  default     = "AWS-TGW-Primary"
}

variable "source_ip" {
  description = "Public IP address of your firewall/router (tunnel source)"
  type        = string
}

variable "source_identity" {
  description = "Source identity for IKE authentication (IP, FQDN, or email format)"
  type        = string
  # Example: "vpn-gateway@acme.com" or "203.0.113.10" or "gateway.acme.com"
}

variable "pre_shared_key" {
  description = "Pre-shared key for IPSec tunnel authentication"
  type        = string
  sensitive   = true
}

variable "primary_pop_name" {
  description = "Primary Netskope POP name (e.g., iad2 for Dulles/Virginia)"
  type        = string
  default     = "iad2"
}

variable "backup_pop_name" {
  description = "Backup/failover Netskope POP name (e.g., atl1 for Atlanta)"
  type        = string
  default     = "atl1"
}

variable "encryption_cipher" {
  description = "Encryption cipher for IPSec tunnel"
  type        = string
  default     = "AES256-GCM"
  validation {
    condition     = contains(["AES128", "AES256", "AES128-GCM", "AES256-GCM"], var.encryption_cipher)
    error_message = "Encryption cipher must be one of: AES128, AES256, AES128-GCM, AES256-GCM."
  }
}

variable "max_bandwidth" {
  description = "Maximum bandwidth for the tunnel in Mbps"
  type        = number
  default     = 250
  validation {
    condition     = contains([50, 100, 250, 500, 1000], var.max_bandwidth)
    error_message = "Maximum bandwidth must be one of: 50, 100, 250, 500, 1000 Mbps."
  }
}

# =============================================================================
# Data Sources - List Available IPSec POPs
# =============================================================================
# Use this to discover available Netskope POPs in your region

data "netskope_ip_sec_po_ps_list" "all_pops" {}

# Look up specific POPs by ID (derived from the POPs list)
locals {
  primary_pop = [for pop in data.netskope_ip_sec_po_ps_list.all_pops.result : pop if pop.pop_name == var.primary_pop_name][0]
  backup_pop  = [for pop in data.netskope_ip_sec_po_ps_list.all_pops.result : pop if pop.pop_name == var.backup_pop_name][0]
}

data "netskope_ip_sec_pop" "primary" {
  pop_id = local.primary_pop.pop_id
}

data "netskope_ip_sec_pop" "backup" {
  pop_id = local.backup_pop.pop_id
}

# =============================================================================
# IPSec Tunnel Resource - Primary Tunnel
# =============================================================================

resource "netskope_ip_sec_tunnel" "primary" {
  site = var.tunnel_name

  # Source configuration - your firewall/router public IP
  source_ip       = var.source_ip
  source_identity = var.source_identity

  # Netskope POP configuration (primary + backup)
  pop_names = [var.primary_pop_name, var.backup_pop_name]

  # Security settings
  psk        = var.pre_shared_key
  encryption = var.encryption_cipher

  # Bandwidth limit
  bandwidth = var.max_bandwidth

  # Optional: Enable SA rekeying (recommended)
  options = {
    rekey = true
  }
}

# =============================================================================
# IPSec Tunnel Resource - Secondary Tunnel (Redundancy)
# =============================================================================
# For high availability, create a second tunnel from the same or different
# source to different POPs

resource "netskope_ip_sec_tunnel" "secondary" {
  site = "${var.tunnel_name}-Backup"

  source_ip       = var.source_ip
  source_identity = "${var.source_identity}-backup"

  # Use backup POP as primary and a different region as backup
  pop_names = [var.backup_pop_name, "sfo1"]

  psk        = var.pre_shared_key
  encryption = var.encryption_cipher
  bandwidth  = var.max_bandwidth

  options = {
    rekey = true
  }
}

# =============================================================================
# Data Source - List Existing IPSec Tunnels
# =============================================================================

data "netskope_ip_sec_tunnels_list" "all_tunnels" {
  depends_on = [
    netskope_ip_sec_tunnel.primary,
    netskope_ip_sec_tunnel.secondary
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "available_pops" {
  description = "List of available Netskope IPSec POPs"
  value       = data.netskope_ip_sec_po_ps_list.all_pops
}

output "primary_pop_details" {
  description = "Primary POP gateway IP address for firewall configuration"
  value = {
    pop_name = data.netskope_ip_sec_pop.primary.pop_name
    gateway  = data.netskope_ip_sec_pop.primary.gateway
    location = data.netskope_ip_sec_pop.primary.location
  }
}

output "backup_pop_details" {
  description = "Backup POP gateway IP address for firewall configuration"
  value = {
    pop_name = data.netskope_ip_sec_pop.backup.pop_name
    gateway  = data.netskope_ip_sec_pop.backup.gateway
    location = data.netskope_ip_sec_pop.backup.location
  }
}

output "primary_tunnel_id" {
  description = "ID of the primary IPSec tunnel"
  value       = netskope_ip_sec_tunnel.primary.tunnel_id
}

output "secondary_tunnel_id" {
  description = "ID of the secondary IPSec tunnel"
  value       = netskope_ip_sec_tunnel.secondary.tunnel_id
}

output "all_tunnels" {
  description = "List of all configured IPSec tunnels"
  value       = data.netskope_ip_sec_tunnels_list.all_tunnels
}

# =============================================================================
# IPSec Configuration Summary for Firewall Configuration
# =============================================================================
# After applying this Terraform configuration, use the output values to
# configure your firewall/router with the following IPSec parameters:
#
# IKE Phase 1 (IKEv2):
#   - Authentication: Pre-Shared Key
#   - Encryption: AES-256 (or as specified)
#   - Hash: SHA-256
#   - DH Group: 14 or 16
#   - Lifetime: 7200 seconds (2 hours)
#
# IKE Phase 2 (IPSec):
#   - Protocol: ESP
#   - Encryption: AES-256 (or as specified)
#   - Hash: SHA-256
#   - PFS: Group 14 or 16
#   - Lifetime: 3600 seconds (1 hour)
#
# Tunnel Configuration:
#   - Local Identity: var.source_identity
#   - Remote Gateway: output.primary_pop_details.gateway
#   - Pre-Shared Key: var.pre_shared_key
# =============================================================================
