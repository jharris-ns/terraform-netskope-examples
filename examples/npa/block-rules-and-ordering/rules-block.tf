# =============================================================================
# Block Rules — requires provider >= 0.4.12
# =============================================================================
#
# Two block rules:
#   block_users            — named user groups (terminated / quarantined)
#   block_unmanaged_devices — any user on an unmanaged (non-corporate) device
#
# ----- Template field -------------------------------------------------------
#
# Set template to the DISPLAY NAME shown in the Netskope UI:
#   Settings > Security Cloud Platform > NPA > Block Templates
#
#   CORRECT:   template = "Generic Block"
#   INCORRECT: template = "5.html"
#
# The provider calls GET /api/v2/templates/usernotifications to translate
# between display names and the .html filenames the API stores internally.
# When that endpoint is accessible the translation is transparent and state
# always holds the display name.
#
# If that endpoint returns 403 on your tenant, the display name is still the
# correct value to put in config — see README.md for the expected plan output.
#
# ----- Update behaviour (fixed in v0.4.12, issue #124) ----------------------
#
# In v0.4.9–0.4.11, any in-place update (changing emit_alert, user_groups,
# users, private_apps, etc.) of a block rule failed with:
#   "API error: template field is required for block action"
# when the templates API returned 403. The BeforeRequest hook was stripping
# the template field from PUT bodies; on tenants that require the field this
# caused every update to be rejected.
#
# v0.4.12 fixes this: the plan modifier now sets the plan value to the config
# display name (not the state filename), so PUT bodies always carry the display
# name, which the API accepts.
#
# ----- Import ---------------------------------------------------------------
#
# To bring an existing UI-created block rule under Terraform management:
#
#   1. Find the rule ID in the Netskope UI or via the API.
#   2. Add the resource block below with the correct template display name.
#   3. terraform import netskope_npa_rules.block_users <rule_id>
#   4. terraform plan — expect exactly one diff: template "5.html" → "Generic Block"
#      This is normal; it reflects the display name correction.
#   5. terraform apply — the rule is now fully managed. Subsequent plans are clean.
#
# =============================================================================

# ---------------------------------------------------------------------------
# Block: terminated / quarantined user groups
# ---------------------------------------------------------------------------
# Created only when blocked_user_groups is non-empty.
# NPA most-specific-match means this takes precedence over any allow rule that
# would otherwise match the same users.
resource "netskope_npa_rules" "block_users" {
  count = length(var.blocked_user_groups) > 0 ? 1 : 0

  rule_name   = "${var.environment}-block-users"
  description = "Block access for terminated or quarantined user accounts"
  enabled     = "1"
  group_id    = var.policy_group_id

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "block"
      emit_alert  = true
      # Display name — NOT the .html filename. See header comment above.
      template = var.block_template
    }

    # Apply to all apps in this example so blocked users cannot reach anything.
    private_apps = [
      netskope_npa_private_app.internal_api.private_app_name,
      netskope_npa_private_app.internal_portal.private_app_name,
    ]

    user_groups   = var.blocked_user_groups
    access_method = ["Client", "Clientless"]
    user_type     = "user"
  }

  # Place at the bottom on create; npa_rules_order positions it at the top.
  # See rules-order.tf.
  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}

# ---------------------------------------------------------------------------
# Block: unmanaged (non-corporate) devices
# ---------------------------------------------------------------------------
# Uses device_classification_id = ["unmanaged"] — the built-in classification
# for devices not enrolled in corporate MDM.
#
# Issue #74 / #106: prior to v0.4.9 the provider rejected the string "unmanaged"
# (only numeric IDs were accepted). Prior to v0.4.9 a read of any rule with
# classification set also crashed with a JSON unmarshal error (issue #106).
# Both are fixed in v0.4.9.
#
# NPA most-specific-match: a managed device matching an allow rule above will
# still be allowed — this rule only catches explicitly unmanaged devices.
resource "netskope_npa_rules" "block_unmanaged_devices" {
  rule_name   = "${var.environment}-block-unmanaged-devices"
  description = "Block Client access from devices not enrolled in corporate MDM"
  enabled     = "1"
  group_id    = var.policy_group_id

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "block"
      emit_alert  = false
      # Display name — NOT the .html filename. See header comment above.
      template = var.block_template
    }

    private_apps = [
      netskope_npa_private_app.internal_api.private_app_name,
    ]

    # "unmanaged" is the built-in string value for devices not enrolled in MDM.
    # To also block specific custom classification states, add their numeric IDs:
    #   device_classification_id = ["unmanaged", "16716"]
    device_classification_id = ["unmanaged"]

    access_method = ["Client"]
    user_type     = "user"
  }

  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}
