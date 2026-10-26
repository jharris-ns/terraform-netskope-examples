# =============================================================================
# General Access Rules
# =============================================================================
# Broader access rules for general user populations.
# These are typically placed lower in the rule order.

# All users browser access to portal applications
# Only created if there are portal apps
resource "netskope_npa_rules" "general_browser_access" {
  count = length(local.portal_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-general-browser-access"
  description = "Allow all authenticated users browser access to portal apps${var.description_suffix}"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Only apps tagged as user-portal
    # IMPORTANT: Do NOT use brackets around app names - causes "Private app [[name]] doesn't exist" error
    private_apps = [for name in local.portal_apps : name]

    # All users
    user_type = "user"

    # Browser only
    access_method = ["Clientless"]
  }

  # rule_order sets the position on CREATE only. The provider does not send it
  # on update (since v0.4.13), so changing it here later has no effect on the
  # live list; netskope_npa_rules_order (rules-order.tf) owns the final order.
  # ignore_changes keeps a later edit of this block from producing a no-op diff.
  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}

# Catch-all deny rule (optional - for explicit deny-by-default)
# Uncomment to enable a default-deny posture for any access not explicitly allowed above.
# Requires a block page template configured in the Netskope UI.
# See rules-deny.tf for a targeted block rule example (blocked users).
#
# resource "netskope_npa_rules" "deny_all_other" {
#   count = length(local.all_app_names) > 0 ? 1 : 0
#
#   rule_name   = "${var.environment}-deny-all-other"
#   description = "Deny all access not explicitly allowed above"
#   enabled     = "1"
#   group_id    = local.default_group.id
#
#   rule_data = {
#     policy_type  = "private-app"
#     json_version = 3
#
#     match_criteria_action = {
#       action_name = "block"
#       emit_alert  = true
#       # Use the template DISPLAY NAME (e.g. "Generic Block"), NOT the file name (e.g. "block_page.html")
#       template = var.block_template
#     }
#
#     # All apps — catch-all for any access not matched by an allow rule above
#     # IMPORTANT: Do NOT use brackets around app names
#     private_apps = [for name in local.all_app_names : name]
#
#     user_type = "user"
#
#     access_method = ["Client", "Clientless"]
#   }
#
#   rule_order = { order = "bottom" }
#
#   lifecycle {
#     ignore_changes = [rule_order]
#   }
# }
#
# Then add netskope_npa_rules.deny_all_other[0].id as the LAST entry in
# local.ordered_rule_ids (rules-order.tf) so it sits at the bottom of the list.
