# =============================================================================
# Allow Rules
# =============================================================================
#
# Three allow rules covering the scenarios from issues #74 and #106:
#
#   allow_admins           — named user groups, no device restriction
#   allow_managed_devices  — any user, managed devices only (Client access)
#   allow_all_client       — catch-all for the clientless portal
#
# device_classification_id accepts both string and numeric values:
#   "managed"   — built-in managed device state (fixed in v0.4.9, issue #74)
#   "unmanaged" — built-in unmanaged device state
#   "16715"     — numeric custom classification tag ID
#
# All rules use:
#   rule_order = { order = "bottom" }     — new rules appear at the bottom,
#                                           away from live traffic, until the
#                                           npa_rules_order resource positions them
#   lifecycle.ignore_changes = [rule_order] — prevents Terraform from re-sending
#                                              rule_order on every update (the API
#                                              ignores it on PUT but it causes drift)
# =============================================================================

# ---------------------------------------------------------------------------
# Allow: admin user groups (no device restriction)
# ---------------------------------------------------------------------------
# Created only when admin_user_groups is non-empty. Allows admins to reach
# both apps from any device and any access method.
resource "netskope_npa_rules" "allow_admins" {
  count = length(var.admin_user_groups) > 0 ? 1 : 0

  rule_name   = "${var.environment}-allow-admins"
  description = "Unrestricted allow for admin groups — no device posture check"
  enabled     = "1"
  group_id    = var.policy_group_id

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [
      netskope_npa_private_app.internal_api.private_app_name,
      netskope_npa_private_app.internal_portal.private_app_name,
    ]

    user_groups   = var.admin_user_groups
    access_method = ["Client", "Clientless"]
    user_type     = "user"
  }

  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}

# ---------------------------------------------------------------------------
# Allow: managed devices only (Client access to internal API)
# ---------------------------------------------------------------------------
# Uses device_classification_id = ["managed"] — the built-in managed device
# classification. The string "managed" was not accepted in v0.4.8 and earlier
# (issue #74, fixed in v0.4.9).
#
# To also include custom classification tag IDs (e.g. "16715" for a specific
# MDM profile), populate var.extra_managed_classification_ids:
#   extra_managed_classification_ids = ["16715", "16758"]
resource "netskope_npa_rules" "allow_managed_devices" {
  rule_name   = "${var.environment}-allow-managed-devices"
  description = "Allow access only from enrolled (managed) corporate devices"
  enabled     = "1"
  group_id    = var.policy_group_id

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [
      netskope_npa_private_app.internal_api.private_app_name,
    ]

    # Combine the built-in "managed" value with any additional tag IDs supplied
    # via the variable. In most cases this is just ["managed"].
    device_classification_id = concat(["managed"], var.extra_managed_classification_ids)

    access_method = ["Client"]
    user_type     = "user"
  }

  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}

# ---------------------------------------------------------------------------
# Allow: catch-all for the clientless portal
# ---------------------------------------------------------------------------
# Any authenticated user can reach the portal app via browser.
# No device posture restriction — clientless access cannot enforce NPA Client
# device state.
resource "netskope_npa_rules" "allow_all_clientless" {
  rule_name   = "${var.environment}-allow-all-clientless"
  description = "Default allow for clientless browser access to the portal"
  enabled     = "1"
  group_id    = var.policy_group_id

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps  = [netskope_npa_private_app.internal_portal.private_app_name]
    access_method = ["Clientless"]
    user_type     = "user"
  }

  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}
