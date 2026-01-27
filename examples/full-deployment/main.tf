# Full NPA Deployment Example
#
# This comprehensive example demonstrates a complete NPA deployment including:
# - Publisher configuration
# - Private applications (client-based access)
# - Policy rules for access control
#
# Use case: Setting up NPA for a new datacenter or application environment
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Private app names in rules must NOT have brackets
#    WRONG: private_apps = ["[${app.name}]"]     (double brackets = error)
#    RIGHT: private_apps = [app.name]            (plain string)
#    Error: "Private app [[name]] doesn't exist"
#
# 2. clientless_access MUST be true for non-HTTP protocols (SSH, RDP, TCP)
#    Despite the name, this is REQUIRED for these protocols to work with NPA client.
#    Error: "Clientless_access need to be set for non-web browser access"
#
# 3. is_user_portal_app may not be allowed on all Netskope tenants
#    If you get "User Portal App cannot be created" error, set this to false
#    and use client-based access instead.
#
# 4. real_host should be a FQDN (not IP address) for HTTPS applications
#    Error: "Enter a FQDN. x.x.x.x is not a valid host"
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

provider "netskope" {}

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
  publisher_id = netskope_npa_publisher.primary.publisher_id
}

resource "netskope_npa_publisher_token" "secondary_token" {
  publisher_id = netskope_npa_publisher.secondary.publisher_id
}

# =============================================================================
# PRIVATE APPLICATIONS
# =============================================================================

# Internal web application (client access via TCP)
resource "netskope_npa_private_app" "web_app" {
  private_app_name     = "${var.environment}-internal-web"
  private_app_hostname = "web.${var.environment}.internal"
  private_app_protocol = "tcp"
  real_host            = "web.internal.local"

  clientless_access  = true
  is_user_portal_app = false

  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  # Assign to both publishers for high availability
  publishers = [
    {
      publisher_id   = tostring(netskope_npa_publisher.primary.publisher_id)
      publisher_name = netskope_npa_publisher.primary.publisher_name
    },
    {
      publisher_id   = tostring(netskope_npa_publisher.secondary.publisher_id)
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

# SSH access to servers
resource "netskope_npa_private_app" "ssh_servers" {
  private_app_name     = "${var.environment}-ssh-access"
  private_app_hostname = "ssh.${var.environment}.internal"
  private_app_protocol = "ssh"
  real_host            = "ssh.internal.local"

  clientless_access  = true
  is_user_portal_app = false

  protocols = [
    {
      port     = "22"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(netskope_npa_publisher.primary.publisher_id)
      publisher_name = netskope_npa_publisher.primary.publisher_name
    },
    {
      publisher_id   = tostring(netskope_npa_publisher.secondary.publisher_id)
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
# POLICY RULES
# =============================================================================

# Create access policy for web application
resource "netskope_npa_rules" "web_app_access" {
  rule_name   = "${var.environment}-web-app-access"
  enabled     = "1"
  description = "Allow authenticated users to access the web application"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [
      netskope_npa_private_app.web_app.private_app_name
    ]

    # Client access
    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order = "top"
  }
}

# Create access policy for SSH
resource "netskope_npa_rules" "ssh_access" {
  rule_name   = "${var.environment}-ssh-access"
  enabled     = "1"
  description = "Allow SSH access"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [
      netskope_npa_private_app.ssh_servers.private_app_name
    ]

    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order   = "after"
    rule_id = tonumber(netskope_npa_rules.web_app_access.id)
  }

  depends_on = [netskope_npa_rules.web_app_access]
}
