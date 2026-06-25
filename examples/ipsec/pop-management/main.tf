# IPSec POP Management
#
# Demonstrates how to discover available Netskope Points of Presence (POPs)
# and create a basic IPSec tunnel. POPs are Netskope-managed infrastructure
# and cannot be created via Terraform — this example shows how to list,
# filter, and inspect them using data sources, then create a tunnel that
# terminates at the selected POP.
#
# What it creates:
#   - A single IPSec tunnel at a selected Netskope POP
#
# What it reads (data sources, no changes to tenant):
#   - All available IPSec POPs with their gateway IPs and status
#   - Full details for the selected POP
#   - All configured tunnels (after creation, to confirm the new tunnel)
#
# Prerequisites:
#   - Netskope tenant with IPSec/GRE license enabled
#   - REST API v2 token with appropriate permissions
#   - Network device (firewall, router, SD-WAN) with a public IP

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

variable "pop_name" {
  description = "Netskope POP short code to use as the tunnel endpoint (e.g., iad2, atl1, sfo1, lon1). Run terraform plan to see available_pops output for all codes."
  type        = string
  default     = "iad2"
}

variable "tunnel_name" {
  description = "Display name for the IPSec tunnel shown in the Netskope UI"
  type        = string
  default     = "My-Office-VPN"
}

variable "source_ip" {
  description = "Public IP address of the firewall or router at the tunnel source"
  type        = string
}

variable "source_identity" {
  description = "IKE identity string — must be unique per tunnel on this tenant (IP address, FQDN, or email format)"
  type        = string
}

variable "pre_shared_key" {
  description = "Pre-shared key (PSK) for IKE authentication — use a strong, unique value"
  type        = string
  sensitive   = true
}

# =============================================================================
# DATA SOURCES — Discover Available POPs
# =============================================================================
# Netskope POPs are managed infrastructure. Use data sources to discover what
# is available and select the best endpoint before creating a tunnel.

# List every IPSec POP available on this tenant
data "netskope_ip_sec_po_ps_list" "all" {}

locals {
  # POPs currently accepting new tunnel connections
  accepting_pops = [
    for pop in data.netskope_ip_sec_po_ps_list.all.result :
    pop if pop.accepting_tunnels
  ]

  # Find the POP matching var.pop_name to get its pop_id for the detail lookup
  selected_pop = [
    for pop in data.netskope_ip_sec_po_ps_list.all.result :
    pop if pop.pop_name == var.pop_name
  ][0]
}

# Look up full details for the selected POP (gateway IP, probe IP, bandwidth tiers)
data "netskope_ip_sec_pop" "selected" {
  pop_id = local.selected_pop.pop_id
}

# =============================================================================
# RESOURCE — IPSec Tunnel
# =============================================================================

resource "netskope_ip_sec_tunnel" "main" {
  site = var.tunnel_name

  # Source: your network device public IP and IKE identity
  source_ip       = var.source_ip
  source_identity = var.source_identity

  # Destination: the selected Netskope POP
  # Add a second POP name here for automatic failover (e.g., ["iad2", "atl1"])
  pop_names = [var.pop_name]

  # Authentication and encryption
  psk        = var.pre_shared_key
  encryption = "AES256-GCM"

  # Bandwidth limit in Mbps — options: 50, 100, 250, 500, 1000
  bandwidth = 50

  options = {
    rekey = true # Re-key IKE SA on expiry (recommended)
  }
}

# =============================================================================
# DATA SOURCES — Verify Created Resources
# =============================================================================

# List all tunnels on the tenant (reads after the tunnel is created)
data "netskope_ip_sec_tunnels_list" "all" {
  depends_on = [netskope_ip_sec_tunnel.main]
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "available_pops_count" {
  description = "Total number of IPSec POPs available on this tenant"
  value       = data.netskope_ip_sec_po_ps_list.all.total
}

output "accepting_pops" {
  description = "POPs currently accepting new tunnel connections — use these short codes in pop_name"
  value = [
    for pop in local.accepting_pops : {
      pop_name = pop.pop_name
      location = pop.location
      region   = pop.region
      gateway  = pop.gateway
    }
  ]
}

output "selected_pop_details" {
  description = "Full details of the POP where this tunnel terminates — use gateway for firewall config"
  value = {
    pop_name  = data.netskope_ip_sec_pop.selected.pop_name
    location  = data.netskope_ip_sec_pop.selected.location
    region    = data.netskope_ip_sec_pop.selected.region
    gateway   = data.netskope_ip_sec_pop.selected.gateway
    probe_ip  = data.netskope_ip_sec_pop.selected.probe_ip
    bandwidth = data.netskope_ip_sec_pop.selected.bandwidth
  }
}

output "tunnel_id" {
  description = "Tunnel ID — use this in netskope_ip_sec_tunnel data source lookups"
  value       = netskope_ip_sec_tunnel.main.tunnel_id
}

output "total_tunnels" {
  description = "Total number of IPSec tunnels now configured on this tenant"
  value       = data.netskope_ip_sec_tunnels_list.all.total
}
