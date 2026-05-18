# RBAC Labels for NPA Resources
#
# This example demonstrates Label-Based Access Control (LBAC) using RBAC labels
# to provide object-level access control on NPA resources.
#
# Use case: Separate management of resources by team, environment, or region.
# Admins with specific label scopes can only see/edit resources tagged with
# their labels.
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Labels support hierarchy up to 4 levels via parent_id.
#    Example: Company > Department > Team > Project
#
# 2. label_ids on resources accepts a list of label UUIDs.
#    Labels must be created before being assigned to resources.
#
# 3. Deleting a label that is in use by roles will fail.
#    Remove label assignments first.
#
# 4. The API token used must have RBAC label management permissions.
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.0"
    }
  }
}

provider "netskope" {}

# =============================================================================
# VARIABLES
# =============================================================================

variable "publisher_name" {
  description = "Name of the publisher to use (null = first available)"
  type        = string
  default     = null
}

variable "team_name" {
  description = "Team name for labels"
  type        = string
  default     = "Engineering"
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "netskope_npa_publishers_list" "all" {}

locals {
  publisher = var.publisher_name != null ? (
    [for p in data.netskope_npa_publishers_list.all.data.publishers : p if p.publisher_name == var.publisher_name][0]
  ) : data.netskope_npa_publishers_list.all.data.publishers[0]
}

# =============================================================================
# RBAC LABEL HIERARCHY
# =============================================================================

# Top-level label (e.g., department)
resource "netskope_rbac_label" "department" {
  name  = var.team_name
  color = "#0294C9"
}

# Child label (e.g., environment within department)
resource "netskope_rbac_label" "production" {
  name      = "${var.team_name}-Production"
  parent_id = netskope_rbac_label.department.label_id
  color     = "#FF5733"
}

resource "netskope_rbac_label" "staging" {
  name      = "${var.team_name}-Staging"
  parent_id = netskope_rbac_label.department.label_id
  color     = "#FFC300"
}

# =============================================================================
# ASSIGN LABELS TO RESOURCES
# =============================================================================

# Private app tagged with production label
resource "netskope_npa_private_app" "prod_app" {
  private_app_name     = "${lower(var.team_name)}-prod-api"
  private_app_hostname = "api.prod.internal.company.com"
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

  # Assign RBAC label - only admins scoped to this label can manage this app
  label_ids = [netskope_rbac_label.production.label_id]
}

# Private app tagged with staging label
resource "netskope_npa_private_app" "staging_app" {
  private_app_name     = "${lower(var.team_name)}-staging-api"
  private_app_hostname = "api.staging.internal.company.com"
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

  label_ids = [netskope_rbac_label.staging.label_id]
}

# =============================================================================
# DISCOVER EXISTING LABELS
# =============================================================================

data "netskope_rbac_label_list" "all" {
  depends_on = [
    netskope_rbac_label.department,
    netskope_rbac_label.production,
    netskope_rbac_label.staging,
  ]
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "label_hierarchy" {
  description = "RBAC label hierarchy"
  value = {
    department = {
      id   = netskope_rbac_label.department.label_id
      name = netskope_rbac_label.department.name
    }
    production = {
      id        = netskope_rbac_label.production.label_id
      name      = netskope_rbac_label.production.name
      parent_id = netskope_rbac_label.production.parent_id
    }
    staging = {
      id        = netskope_rbac_label.staging.label_id
      name      = netskope_rbac_label.staging.name
      parent_id = netskope_rbac_label.staging.parent_id
    }
  }
}

output "all_labels" {
  description = "All RBAC labels on this tenant"
  value = [
    for l in data.netskope_rbac_label_list.all.labels : {
      id        = l.label_id
      name      = l.name
      parent_id = l.parent_id
      color     = l.color
    }
  ]
}
