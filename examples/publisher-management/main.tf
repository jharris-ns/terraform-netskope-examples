# Publisher Management Example
#
# This example demonstrates publisher lifecycle management including:
# - Creating and configuring publishers
# - Setting up upgrade profiles for automated updates
# - Configuring alerts for publisher events
# - Managing publisher groups for bulk operations
#
# Use case: Managing a fleet of NPA publishers across multiple locations
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Upgrade profile names MUST be 20 characters or less
#    WRONG: name = "Production-Weekly-Upgrades"  (26 chars - will fail)
#    RIGHT: name = "Prod-Weekly"                 (11 chars - OK)
#    Error: "Field 'name' exceeds maximum length of 20 characters"
#
# 2. Timezone format uses POSIX style, not IANA
#    WRONG: timezone = "America/Los_Angeles"
#    RIGHT: timezone = "US/Pacific"
#
# 3. Alerts configuration requires VALID admin emails from your tenant
#    The admin_users must be actual users that exist in your Netskope tenant.
#    Error: "Admin mail ID does not exist"
#    See the commented-out example below for the alerts resource.
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
# DATA SOURCES - Query Existing Resources
# =============================================================================

# Get list of all publishers
data "netskope_npa_publishers_list" "all" {}

# Get available release versions
data "netskope_npa_publishers_releases_list" "releases" {}

# Get current alerts configuration
data "netskope_npa_publishers_alerts_configuration" "current" {}

# =============================================================================
# UPGRADE PROFILES
# =============================================================================

# Create a weekly upgrade profile for production publishers
resource "netskope_npa_publisher_upgrade_profile" "production_weekly" {
  name     = "Prod-Weekly"
  enabled  = true
  timezone = "US/Pacific"

  # Frequency uses standard cron format: minute hour day-of-month month day-of-week
  # Schedule: Sundays at 2 AM Pacific
  docker_tag   = data.netskope_npa_publishers_releases_list.releases.data[1].docker_tag # Latest stable
  frequency    = "0 2 * * 0" # minute=0, hour=2, any day, any month, Sunday
  release_type = "Latest"
}

# Create a more aggressive upgrade profile for staging
resource "netskope_npa_publisher_upgrade_profile" "staging_daily" {
  name     = "Staging-Daily"
  enabled  = true
  timezone = "US/Pacific"

  # Frequency uses standard cron format: minute hour day-of-month month day-of-week
  # Schedule: Daily at midnight Pacific
  docker_tag   = data.netskope_npa_publishers_releases_list.releases.data[0].docker_tag # Beta
  frequency    = "0 0 * * *" # Daily at midnight
  release_type = "Beta"
}

# =============================================================================
# PUBLISHERS BY LOCATION
# =============================================================================

# US West Coast Publishers
resource "netskope_npa_publisher" "us_west_1" {
  publisher_name = "us-west-datacenter-1"
}

resource "netskope_npa_publisher" "us_west_2" {
  publisher_name = "us-west-datacenter-2"
}

# US East Coast Publishers
resource "netskope_npa_publisher" "us_east_1" {
  publisher_name = "us-east-datacenter-1"
}

# European Publishers
resource "netskope_npa_publisher" "eu_west_1" {
  publisher_name = "eu-west-datacenter-1"
}

# Generate registration tokens
resource "netskope_npa_publisher_token" "us_west_1" {
  publisher_id = netskope_npa_publisher.us_west_1.publisher_id
}

resource "netskope_npa_publisher_token" "us_west_2" {
  publisher_id = netskope_npa_publisher.us_west_2.publisher_id
}

resource "netskope_npa_publisher_token" "us_east_1" {
  publisher_id = netskope_npa_publisher.us_east_1.publisher_id
}

resource "netskope_npa_publisher_token" "eu_west_1" {
  publisher_id = netskope_npa_publisher.eu_west_1.publisher_id
}

# =============================================================================
# ALERTS CONFIGURATION
# =============================================================================

# Configure alerts for publisher events
# NOTE: Requires valid admin email addresses that exist in your Netskope tenant
#
# WARNING: The valid event_types for alerts are not fully documented in the API.
# Values like "publisher_up" and "publisher_down" may be rejected.
# The event types shown below are examples - test in non-production first.
#
# Uncomment and configure with your actual admin emails:
#
# resource "netskope_npa_publishers_alerts_configuration" "alerts" {
#   admin_users    = ["your-admin@company.com"]
#   selected_users = "your-admin@company.com"
#   event_types = [
#     "UPGRADE_WILL_START",
#     "UPGRADE_STARTED",
#     "UPGRADE_SUCCEEDED",
#     "UPGRADE_FAILED",
#     "CONNECTION_FAILED"
#   ]
# }

# =============================================================================
# OUTPUTS
# =============================================================================

output "publisher_registration_tokens" {
  description = "Registration tokens for each publisher (sensitive)"
  sensitive   = true
  value = {
    us_west_1 = netskope_npa_publisher_token.us_west_1.token
    us_west_2 = netskope_npa_publisher_token.us_west_2.token
    us_east_1 = netskope_npa_publisher_token.us_east_1.token
    eu_west_1 = netskope_npa_publisher_token.eu_west_1.token
  }
}

output "upgrade_profiles" {
  description = "Created upgrade profiles"
  value = {
    production = {
      name       = netskope_npa_publisher_upgrade_profile.production_weekly.name
      frequency  = netskope_npa_publisher_upgrade_profile.production_weekly.frequency
      docker_tag = netskope_npa_publisher_upgrade_profile.production_weekly.docker_tag
    }
    staging = {
      name       = netskope_npa_publisher_upgrade_profile.staging_daily.name
      frequency  = netskope_npa_publisher_upgrade_profile.staging_daily.frequency
      docker_tag = netskope_npa_publisher_upgrade_profile.staging_daily.docker_tag
    }
  }
}

output "available_releases" {
  description = "Available publisher release versions"
  value = [for r in data.netskope_npa_publishers_releases_list.releases.data : {
    name       = r.name
    version    = r.version
    docker_tag = r.docker_tag
  }]
}

output "all_publishers" {
  description = "List of all publishers in the tenant"
  value = [for p in data.netskope_npa_publishers_list.all.data.publishers : {
    id     = p.publisher_id
    name   = p.publisher_name
    status = p.status
  }]
}
