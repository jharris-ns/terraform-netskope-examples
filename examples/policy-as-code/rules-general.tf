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
  description = "Allow all authenticated users browser access to portal apps"
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

  rule_order = {
    order = "bottom"
  }
}

# Catch-all deny rule (optional - for explicit deny-by-default)
# Only created if there are apps to protect
resource "netskope_npa_rules" "deny_all_other" {
  count = length(local.all_app_names) > 0 ? 1 : 0

  rule_name   = "${var.environment}-deny-all-other"
  description = "Deny all access not explicitly allowed above"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "block"
    }

    # All apps
    # IMPORTANT: Do NOT use brackets around app names
    private_apps = [for name in local.all_app_names : name]

    user_type = "user"

    access_method = ["Client", "Clientless"]
  }

  rule_order = {
    order = "bottom"
  }

  # Ensure this is truly last
  depends_on = [
    netskope_npa_rules.general_browser_access
  ]
}
