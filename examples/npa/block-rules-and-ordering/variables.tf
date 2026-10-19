variable "environment" {
  description = "Environment label used in resource names (e.g. 'prod', 'staging', 'example')."
  type        = string
  default     = "example"
}

# ---------------------------------------------------------------------------
# Policy group
# ---------------------------------------------------------------------------

variable "policy_group_id" {
  description = <<-EOT
    ID of an existing NPA policy group to place rules into.
    Look up available groups with:
      data "netskope_npa_policy_groups_list" "all" {}
      output "groups" { value = data.netskope_npa_policy_groups_list.all.data }
  EOT
  type        = string
}

# ---------------------------------------------------------------------------
# Block template
# ---------------------------------------------------------------------------

variable "block_template" {
  description = <<-EOT
    Display name of the NPA block page template as shown in the Netskope UI:
      Settings > Security Cloud Platform > NPA > Block Templates

    Must be the display name (e.g. "Generic Block"), NOT the underlying .html
    filename (e.g. "5.html"). The provider translates between the two
    automatically when /api/v2/templates/usernotifications is accessible.

    If that endpoint returns 403 on your tenant, supply the display name anyway —
    see README.md for the expected one-time plan behaviour.
  EOT
  type        = string
  default     = "Generic Block"
}

# ---------------------------------------------------------------------------
# User groups (from your IdP)
# ---------------------------------------------------------------------------

variable "blocked_user_groups" {
  description = <<-EOT
    User groups to block from all private apps — typically terminated employees
    or accounts under quarantine. Must match group names exactly as they appear
    in your IdP integration.
    If empty, the block-by-user-group rule is not created.
  EOT
  type        = list(string)
  default     = []
}

variable "admin_user_groups" {
  description = <<-EOT
    User groups that should have unrestricted allow access to all private apps.
    Must match group names exactly as they appear in your IdP integration.
    If empty, the admin allow rule is not created.
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Device classification
# ---------------------------------------------------------------------------

variable "extra_managed_classification_ids" {
  description = <<-EOT
    Optional additional numeric device classification tag IDs to include in the
    "managed devices only" allow rule alongside the built-in "managed" value.
    Find IDs with:
      data "netskope_device_classification_options_list" "all" {}
    Example: ["16715", "16758"]
  EOT
  type        = list(string)
  default     = []
}
