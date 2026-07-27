# RBAC Roles for Netskope Administration
#
# This example demonstrates how to manage custom admin roles using Role-Based
# Access Control (RBAC). Each role defines which API groups an administrator
# can access and at what permission level.
#
# Use case: Version-control your admin role definitions so that role changes
# are auditable, reviewable, and reproducible across tenants.
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. api_group_id values are tenant-specific integers. Discover yours by
#    querying GET /api/v2/rbac/roles/config (requires the 'roles' API group
#    with at least read permission). The IDs below are illustrative.
#
# 2. Only custom roles (type = 0) can be created or updated via the API.
#    Predefined (system) roles are read-only and can only be read via the
#    data source.
#
# 3. Deleting a role that is assigned to users will fail with a 409 error.
#    Unassign users before running terraform destroy.
#
# 4. The API token used must have the 'roles' API group with rw permission.
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.8"
    }
  }
}

provider "netskope" {}

# =============================================================================
# VARIABLES
# =============================================================================

variable "auditor_role_name" {
  description = "Name for the read-only auditor role"
  type        = string
  default     = "Security Auditor"
}

variable "operator_role_name" {
  description = "Name for the NPA operator role"
  type        = string
  default     = "NPA Operator"
}

variable "corporate_ip_ranges" {
  description = "IP ranges to restrict operator access (CIDR notation or single IPs)"
  type        = list(string)
  default     = ["10.0.0.0/8", "192.168.0.0/16"]
}

# =============================================================================
# READ-ONLY AUDITOR ROLE
# =============================================================================
#
# A read-only role suitable for security auditors who need visibility across
# the platform without the ability to make changes.
#
# To find api_group_id values for your tenant:
#   curl -H "Netskope-Api-Token: $NETSKOPE_API_KEY" \
#        "$NETSKOPE_SERVER_URL/rbac/roles/config" | jq '.apiGroups[] | {id: .apiGroupId, name: .apiGroupName}'

resource "netskope_rbac_role" "auditor" {
  name        = var.auditor_role_name
  description = "Read-only access for security auditors. Managed by Terraform."

  api_groups = [
    # NPA - private apps (read)
    {
      api_group_id = 1
      permission   = "r"
    },
    # NPA - publishers (read)
    {
      api_group_id = 2
      permission   = "r"
    },
    # NPA - policy rules (read)
    {
      api_group_id = 3
      permission   = "r"
    },
    # URL lists (read)
    {
      api_group_id = 10
      permission   = "r"
    },
    # RBAC roles (read)
    {
      api_group_id = 107
      permission   = "r"
    },
  ]
}

# =============================================================================
# NPA OPERATOR ROLE
# =============================================================================
#
# A read-write role for the team responsible for managing NPA infrastructure.
# Restricted to corporate IP ranges to limit where this elevated role can be used.

resource "netskope_rbac_role" "npa_operator" {
  name        = var.operator_role_name
  description = "Read-write access to NPA resources. Restricted to corporate network. Managed by Terraform."

  api_groups = [
    # NPA - private apps (read-write)
    {
      api_group_id = 1
      permission   = "rw"
    },
    # NPA - publishers (read-write)
    {
      api_group_id = 2
      permission   = "rw"
    },
    # NPA - policy rules (read-write)
    {
      api_group_id = 3
      permission   = "rw"
    },
    # URL lists (read only - operators can see but not modify)
    {
      api_group_id = 10
      permission   = "r"
    },
  ]

  # Restrict this elevated role to corporate network only
  ip_allow_list = {
    enable_ip_allow_list = true
    ip_list              = var.corporate_ip_ranges
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Look up the auditor role by its assigned ID (useful for referencing in other configs)
data "netskope_rbac_role" "auditor" {
  role_id    = netskope_rbac_role.auditor.role_id
  depends_on = [netskope_rbac_role.auditor]
}

# List all roles on the tenant (custom and predefined)
data "netskope_rbac_role_list" "all" {
  depends_on = [
    netskope_rbac_role.auditor,
    netskope_rbac_role.npa_operator,
  ]
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "auditor_role" {
  description = "Auditor role details"
  value = {
    role_id    = netskope_rbac_role.auditor.role_id
    name       = netskope_rbac_role.auditor.name
    api_groups = netskope_rbac_role.auditor.api_groups
  }
}

output "operator_role" {
  description = "NPA operator role details"
  value = {
    role_id          = netskope_rbac_role.npa_operator.role_id
    name             = netskope_rbac_role.npa_operator.name
    ip_allow_enabled = netskope_rbac_role.npa_operator.ip_allow_list.enable_ip_allow_list
  }
}

output "all_role_names" {
  description = "Names of all roles on this tenant (custom and predefined)"
  value       = [for r in data.netskope_rbac_role_list.all.roles : r.name]
}
