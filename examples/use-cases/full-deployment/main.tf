# Full NPA Deployment Example
#
# This comprehensive example demonstrates a complete NPA deployment including:
# - Publisher configuration
# - Private applications (both browser and client-based)
# - Policy groups and access rules
#
# Use case: Setting up NPA for a new datacenter or application environment

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

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "datacenter_name" {
  description = "Name of the datacenter"
  type        = string
  default     = "us-west-dc1"
}

# =============================================================================
# PUBLISHERS
# =============================================================================

# Create primary publisher for the datacenter
resource "netskope_npa_publisher" "primary" {
  publisher_name = "${var.datacenter_name}-primary"
}

# Create secondary publisher for redundancy
resource "netskope_npa_publisher" "secondary" {
  publisher_name = "${var.datacenter_name}-secondary"
}

# Generate registration tokens for the publishers
resource "netskope_npa_publisher_token" "primary_token" {
  publisher_id = netskope_npa_publisher.primary.id
}

resource "netskope_npa_publisher_token" "secondary_token" {
  publisher_id = netskope_npa_publisher.secondary.id
}

# =============================================================================
# PRIVATE APPLICATIONS
# =============================================================================

# Internal web application (browser access)
resource "netskope_npa_private_app" "web_portal" {
  private_app_name     = "${var.environment}-web-portal"
  private_app_hostname = "portal.${var.environment}.internal"
  private_app_protocol = "https"
  real_host            = "10.100.1.10"

  clientless_access  = true
  is_user_portal_app = true

  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  # Assign to both publishers for high availability
  publishers = [
    {
      publisher_id   = tostring(netskope_npa_publisher.primary.id)
      publisher_name = netskope_npa_publisher.primary.publisher_name
    },
    {
      publisher_id   = tostring(netskope_npa_publisher.secondary.id)
      publisher_name = netskope_npa_publisher.secondary.publisher_name
    }
  ]

  tags = [
    { tag_name = var.environment },
    { tag_name = "web" }
  ]

  use_publisher_dns       = true
  trust_self_signed_certs = false
}

# SSH access to servers (client-only)
resource "netskope_npa_private_app" "ssh_servers" {
  private_app_name     = "${var.environment}-ssh-access"
  private_app_hostname = "ssh.${var.environment}.internal"
  private_app_protocol = "ssh"
  real_host            = "10.100.1.0/24"  # Entire subnet

  clientless_access  = false
  is_user_portal_app = false

  protocols = [
    {
      port     = "22"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(netskope_npa_publisher.primary.id)
      publisher_name = netskope_npa_publisher.primary.publisher_name
    },
    {
      publisher_id   = tostring(netskope_npa_publisher.secondary.id)
      publisher_name = netskope_npa_publisher.secondary.publisher_name
    }
  ]

  tags = [
    { tag_name = var.environment },
    { tag_name = "infrastructure" }
  ]

  use_publisher_dns = true
}

# =============================================================================
# POLICY CONFIGURATION
# =============================================================================

# Look up existing policy groups
data "netskope_npa_policy_groups_list" "all" {}

# Create access policy for web portal
resource "netskope_npa_rules" "web_portal_access" {
  rule_name   = "${var.environment}-web-portal-access"
  enabled     = "1"
  description = "Allow authenticated users to access the web portal"

  rule_data = {
    policy_type = "private-app"
    json_version = 3

    # Allow access
    match_criteria_action = {
      action_name = "allow"
    }

    # Apply to the web portal app
    private_apps = [
      "[${netskope_npa_private_app.web_portal.private_app_name}]"
    ]

    # Access method - browser only
    access_method = ["Clientless"]

    # User type
    user_type = "user"
  }

  # Place rule at the top of the policy
  rule_order = {
    order = "top"
  }
}

# Create access policy for SSH (more restrictive)
resource "netskope_npa_rules" "ssh_access" {
  rule_name   = "${var.environment}-ssh-admin-access"
  enabled     = "1"
  description = "Allow infrastructure team SSH access"

  rule_data = {
    policy_type = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [
      "[${netskope_npa_private_app.ssh_servers.private_app_name}]"
    ]

    # Client access only
    access_method = ["Client"]

    user_type = "user"

    # Restrict to specific user group (update with your group name)
    user_groups = ["Infrastructure-Admins"]
  }

  rule_order = {
    order    = "after"
    rule_id  = tonumber(netskope_npa_rules.web_portal_access.id)
  }

  depends_on = [netskope_npa_rules.web_portal_access]
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "publisher_tokens" {
  description = "Registration tokens for the publishers (use these to register the publisher VMs)"
  sensitive   = true
  value = {
    primary   = netskope_npa_publisher_token.primary_token.token
    secondary = netskope_npa_publisher_token.secondary_token.token
  }
}

output "web_portal_url" {
  description = "Browser access URL for the web portal"
  value       = netskope_npa_private_app.web_portal.app_url
}

output "ssh_hostname" {
  description = "Hostname for SSH access via NPA client"
  value       = netskope_npa_private_app.ssh_servers.private_app_hostname
}

output "publishers" {
  description = "Created publishers"
  value = {
    primary = {
      id   = netskope_npa_publisher.primary.id
      name = netskope_npa_publisher.primary.publisher_name
    }
    secondary = {
      id   = netskope_npa_publisher.secondary.id
      name = netskope_npa_publisher.secondary.publisher_name
    }
  }
}
