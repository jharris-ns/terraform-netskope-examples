# =============================================================================
# Team-Based Access Rules
# =============================================================================
# These rules grant access based on team membership.

# Developer access to web applications
resource "netskope_npa_rules" "developer_web_access" {
  count = length(local.web_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-developer-web-access"
  description = "Allow developers browser access to web applications"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # IMPORTANT: Do NOT use brackets around app names - causes "Private app [[name]] doesn't exist" error
    private_apps = [for name in local.web_apps : name]

    user_groups = var.developer_groups

    # Browser and client access
    access_method = ["Client", "Clientless"]

    user_type = "user"
  }

  rule_order = {
    order = "bottom"
  }
}

# DBA database access
resource "netskope_npa_rules" "dba_readonly_access" {
  count = length(local.database_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-dba-database-access"
  description = "Allow DBA team access to databases"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # IMPORTANT: Do NOT use brackets around app names
    private_apps = [for name in local.database_apps : name]

    user_groups = var.dba_groups

    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order = "bottom"
  }

  depends_on = [netskope_npa_rules.developer_web_access]
}
