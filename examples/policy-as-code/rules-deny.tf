# =============================================================================
# Deny Rules
# =============================================================================
# These rules are placed at the top and evaluated first.
# Deny rules should explicitly block access for specific conditions.

# Block terminated/quarantined users from all access
# Only created if blocked_groups is not empty AND there are apps to protect
resource "netskope_npa_rules" "deny_blocked_users" {
  count = length(var.blocked_groups) > 0 && length(local.all_app_names) > 0 ? 1 : 0

  rule_name   = "${var.environment}-deny-blocked-users"
  description = "Block access for terminated and quarantined users"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    # Deny action
    match_criteria_action = {
      action_name = "block"
    }

    # Apply to all apps
    # IMPORTANT: Do NOT use brackets around app names - causes "Private app [[name]] doesn't exist" error
    private_apps = [for name in local.all_app_names : name]

    # Target blocked groups
    user_groups = var.blocked_groups

    # All access methods
    access_method = ["Client", "Clientless"]

    # User type
    user_type = "user"
  }

  # Place at the very top
  rule_order = {
    order = "top"
  }
}
