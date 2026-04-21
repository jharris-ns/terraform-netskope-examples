# Local Broker Management Example
#
# This example demonstrates local broker lifecycle management including:
# - Creating and configuring local brokers
# - Setting up local broker hostname configuration
# - Generating registration tokens
# - Querying local broker information
#
# Use case: Managing NPA local brokers for on-premises connectivity
#
# =============================================================================
# WHAT IS A LOCAL BROKER?
# =============================================================================
#
# A Local Broker (LBR) is a lightweight component that enables Netskope Private
# Access (NPA) to route traffic to private applications within your network.
# Unlike publishers which run in your data center, local brokers provide
# additional routing flexibility for complex network topologies.
#
# Local brokers are useful when:
# - You need to route traffic through specific network paths
# - You have multiple network segments that require different routing
# - You want to optimize traffic flow for geographically distributed apps
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Local broker names should be descriptive and unique within your tenant
#
# 2. The access_via_public_ip setting controls how clients can reach the broker:
#    - NONE: No public IP access (default)
#    - OFF_PREM: Allow access from off-premises clients via public IP
#    - ON_PREM: Allow access from on-premises clients via public IP
#    - ON_OFF_PREM: Allow access from both on and off-premises via public IP
#
# 3. Registration tokens are one-time use - generate a new token for each
#    broker registration
#
# 4. The hostname configuration is tenant-wide and affects all local brokers
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.4"
    }
  }
}

provider "netskope" {
  # Configure via environment variables:
  # NETSKOPE_SERVER_URL = "https://your-tenant.goskope.com/api/v2"
  # NETSKOPE_API_KEY    = "your-api-token"
}

# =============================================================================
# DATA SOURCES - Query Existing Resources
# =============================================================================

# Get list of all local brokers
data "netskope_npa_local_brokers_list" "all" {}

# Get current hostname configuration
data "netskope_npa_local_broker_config" "current" {}

# =============================================================================
# LOCAL BROKER CONFIGURATION (Tenant-Wide)
# =============================================================================

# Configure the hostname used for local broker connections
# This is a tenant-wide setting that applies to all local brokers
resource "netskope_npa_local_broker_config" "main" {
  hostname = "lbroker.example.internal"
}

# =============================================================================
# LOCAL BROKERS
# =============================================================================

# Example 1: Basic local broker with minimal configuration
resource "netskope_npa_local_broker" "datacenter_primary" {
  local_broker_name = "dc-primary-lbr"
}

# Example 2: Local broker with full location information
resource "netskope_npa_local_broker" "datacenter_west" {
  local_broker_name = "dc-west-lbr"

  # Location information helps with geographic routing decisions
  city_name    = "San Francisco"
  region_name  = "CA"
  country_name = "United States of America"
  country_code = "US"

  # Geographic coordinates for proximity-based routing
  latitude  = 37.7749
  longitude = -122.4194

  # Custom IP addresses (optional)
  # Use these if the broker should be reachable at specific IPs
  # custom_public_ip  = "203.0.113.10"
  # custom_private_ip = "10.0.1.100"

  # Access mode - controls how clients can reach the broker via public IP
  access_via_public_ip = "NONE"
}

# Example 3: Local broker for branch office with public IP access
resource "netskope_npa_local_broker" "branch_east" {
  local_broker_name = "branch-east-lbr"

  city_name    = "New York"
  region_name  = "NY"
  country_name = "United States of America"
  country_code = "US"

  latitude  = 40.7128
  longitude = -74.0060

  # Allow off-premises clients to reach this broker via public IP
  access_via_public_ip = "OFF_PREM"
}

# =============================================================================
# REGISTRATION TOKENS
# =============================================================================

# Generate a registration token for the primary datacenter broker
# Note: Tokens are one-time use - generate a new token each time you need
# to register or re-register a broker
resource "netskope_npa_local_broker_token" "datacenter_primary" {
  local_broker_id = netskope_npa_local_broker.datacenter_primary.local_broker_id
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "all_local_brokers" {
  description = "List of all local brokers in the tenant"
  value       = data.netskope_npa_local_brokers_list.all.data
}

output "hostname_config" {
  description = "Current local broker hostname configuration"
  value       = data.netskope_npa_local_broker_config.current.data
}

output "primary_broker_id" {
  description = "ID of the primary datacenter local broker"
  value       = netskope_npa_local_broker.datacenter_primary.local_broker_id
}

output "primary_broker_registration_token" {
  description = "Registration token for the primary datacenter broker (sensitive)"
  value       = netskope_npa_local_broker_token.datacenter_primary.data.token
  sensitive   = true
}

output "west_broker_id" {
  description = "ID of the west datacenter local broker"
  value       = netskope_npa_local_broker.datacenter_west.local_broker_id
}

output "east_broker_id" {
  description = "ID of the east branch local broker"
  value       = netskope_npa_local_broker.branch_east.local_broker_id
}