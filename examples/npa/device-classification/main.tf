# Device Classification in NPA Rules
#
# This example demonstrates how to use device classification tags to enforce
# device posture policies. Only devices matching specific classifications
# (e.g., "CrowdStrike Installed") are allowed access.
#
# Use case: Restrict private app access to managed devices with endpoint
# protection, or block unmanaged/untrusted devices.
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Device classification tags are created in the Netskope UI:
#    Settings > Device Classification
#    Tags cannot be created via Terraform - only looked up.
#
# 2. device_classification_id expects a list of STRINGS containing numeric IDs.
#    Use tostring() to convert the tag_id (integer) to string.
#    The provider automatically converts strings to integers for the API.
#
# 3. Multiple IDs in device_classification_id are OR'd together -
#    the device must match ANY of the listed classifications.
#
# 4. This example requires at least one device classification tag
#    to exist in your tenant and at least one publisher.
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.2"
    }
  }
}

provider "netskope" {}

# =============================================================================
# VARIABLES
# =============================================================================

variable "required_tag_name" {
  description = "Name of the device classification tag to require (must exist in Netskope UI)"
  type        = string
  default     = "CrowdStrike Installed"
}

variable "publisher_name" {
  description = "Name of the publisher to use (null = first available)"
  type        = string
  default     = null
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Discover all device classification tags
data "netskope_device_classification_tag_list" "all" {}

# Look up publisher
data "netskope_npa_publishers_list" "all" {}

# Look up policy groups
data "netskope_npa_policy_groups_list" "all" {}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  # Build a map of tag name -> tag ID for easy lookup
  tag_ids_by_name = {
    for t in data.netskope_device_classification_tag_list.all.tags :
    t.name => t.tag_id
  }

  # Find the required tag (empty list if not found)
  matching_tags = [
    for t in data.netskope_device_classification_tag_list.all.tags :
    t if t.name == var.required_tag_name
  ]

  # Publisher selection
  publisher = var.publisher_name != null ? (
    [for p in data.netskope_npa_publishers_list.all.data.publishers : p if p.publisher_name == var.publisher_name][0]
  ) : data.netskope_npa_publishers_list.all.data.publishers[0]

  # Default policy group
  default_group = [
    for pg in data.netskope_npa_policy_groups_list.all.data :
    pg if pg.group_name == "Default"
  ][0]
}

# =============================================================================
# PRIVATE APP (for demonstration)
# =============================================================================

resource "netskope_npa_private_app" "secure_app" {
  private_app_name     = "Secure Internal App"
  private_app_hostname = "secure.internal.company.com"
  clientless_access    = false
  is_user_portal_app   = false

  protocols = [
    {
      port     = "443"
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

# =============================================================================
# NPA RULE WITH DEVICE CLASSIFICATION
# =============================================================================

# Only allow access from devices matching the required classification
resource "netskope_npa_rules" "posture_required" {
  rule_name   = "require-endpoint-protection"
  description = "Allow access only from devices with ${var.required_tag_name}"
  enabled     = "1"
  group_id    = local.default_group.id

  # Fail early if the tag doesn't exist on this tenant
  lifecycle {
    precondition {
      condition     = length(local.matching_tags) > 0
      error_message = "Device classification tag '${var.required_tag_name}' not found. Create it in Settings > Device Classification."
    }
  }

  rule_data = {
    policy_type = "private-app"

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps  = [netskope_npa_private_app.secure_app.private_app_name]
    access_method = ["Client"]

    # Require device to match the classification
    # tostring() converts the integer tag_id to the string format the provider expects
    device_classification_id = [tostring(local.matching_tags[0].tag_id)]
  }

  rule_order = {
    order = "top"
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "all_tags" {
  description = "All device classification tags available on this tenant"
  value = [
    for t in data.netskope_device_classification_tag_list.all.tags : {
      id       = t.tag_id
      name     = t.name
      priority = t.priority
    }
  ]
}

output "selected_tag" {
  description = "The device classification tag used in the rule"
  value = length(local.matching_tags) > 0 ? {
    id   = local.matching_tags[0].tag_id
    name = local.matching_tags[0].name
  } : null
}

output "tag_lookup_map" {
  description = "Name-to-ID map for all device classification tags"
  value       = local.tag_ids_by_name
}
