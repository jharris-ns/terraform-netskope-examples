# =============================================================================
# Block Rules — requires provider >= 0.4.13
# =============================================================================
#
# Two block rules:
#   block_users             — named user groups (terminated / quarantined)
#   block_unmanaged_devices — any user on an unmanaged (non-corporate) device
#
# ----- Template field -------------------------------------------------------
#
# Set template to the DISPLAY NAME shown in the Netskope UI:
#   Settings > Security Cloud Platform > NPA > Block Templates
#
#   CORRECT:   template = "Generic Block"
#   INCORRECT: template = "block_page.html"
#
# The API accepts the display name on write but returns an internal filename
# on read. The provider reconciles the two via Terraform private state, so:
#   - the first plan after create or import shows ONE diff per block rule,
#       template = "block_page.html" -> "Generic Block"
#     apply it; every plan after that is empty, on any machine or TFC run;
#   - in-place updates (emit_alert, user_groups, ...) send the display name
#     and succeed;
#   - changing the display name in config is detected and applied.
# No extra API endpoint is needed for block rules.
#
# ----- Import ---------------------------------------------------------------
#
#   1. Find the rule ID in the Netskope UI or via the API.
#   2. Add the resource block below with the template display name.
#   3. terraform import netskope_npa_rules.block_users <rule_id>
#   4. terraform plan — exactly one diff: template "block_page.html" -> "Generic Block"
#   5. terraform apply — the rule is now fully managed. Subsequent plans are empty.
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
  description = "Block access for terminated or quarantined user accounts${var.description_suffix}"
  enabled     = "1"
  group_id    = local.policy_group.id

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

  # rule_order sets the position on CREATE only. The provider does not send it
  # on update (since v0.4.13), so changing it here later has no effect on the
  # live list; use netskope_npa_rules_order (rules-order.tf) for that.
  # ignore_changes keeps a later edit of this block from producing a no-op diff.
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
# "unmanaged" is set via the classification field (not device_classification_id).
# device_classification_id is for numeric custom tag IDs only. Using "unmanaged"
# in device_classification_id causes the API to reject the request with
# "device_classification_id should be integer".
#
# NPA most-specific-match: a managed device matching an allow rule above will
# still be allowed — this rule only catches explicitly unmanaged devices.
resource "netskope_npa_rules" "block_unmanaged_devices" {
  rule_name   = "${var.environment}-block-unmanaged-devices"
  description = "Block Client access from devices not enrolled in corporate MDM${var.description_suffix}"
  enabled     = "1"
  group_id    = local.policy_group.id

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

    # "unmanaged" is the built-in value for devices not enrolled in corporate MDM.
    # Set via the classification field — NOT device_classification_id, which is
    # for custom numeric tag IDs only.
    # To also block specific custom classification states, add their numeric IDs:
    #   device_classification_id = ["16716"]
    classification = ["unmanaged"]

    access_method = ["Client"]
    user_type     = "user"
  }

  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}
