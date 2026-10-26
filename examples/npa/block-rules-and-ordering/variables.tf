variable "environment" {
  description = "Environment label used in resource names (e.g. 'prod', 'staging', 'example')."
  type        = string
  default     = "example"
}

# ---------------------------------------------------------------------------
# Policy group
# ---------------------------------------------------------------------------

variable "policy_group_name" {
  description = <<-EOT
    Name of the NPA policy group to place rules into.
    Defaults to the built-in "Default" group if not specified.
    List available groups with:
      data "netskope_npa_policy_groups_list" "all" {}
      output "groups" { value = data.netskope_npa_policy_groups_list.all.data }
  EOT
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Block template
# ---------------------------------------------------------------------------

variable "block_template" {
  description = <<-EOT
    Display name of the NPA block page template as shown in the Netskope UI:
      Settings > Security Cloud Platform > NPA > Block Templates

    Must be the display name (e.g. "Generic Block"), NOT the underlying .html
    filename (e.g. "block_page.html"). The API returns the filename on read;
    the provider reconciles the two. Expect one "block_page.html" -> "<name>"
    diff on the first plan after create or import, then empty plans. See README.md.
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
    "managed devices only" allow rule alongside the built-in "managed" classification.
    These are set in device_classification_id (numeric custom tags only — NOT the
    built-in "managed"/"unmanaged" string values, which go in classification).
    Find IDs with:
      data "netskope_device_classification_options_list" "all" {}
    Example: ["16715", "16758"]
  EOT
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Test hook
# ---------------------------------------------------------------------------

variable "description_suffix" {
  description = <<-EOT
    Optional text appended to every rule description. Used by the integration
    test harness to exercise an in-place update of every rule (verifying that
    updates succeed and do not change rule positions). Leave empty normally.
  EOT
  type        = string
  default     = ""
}
