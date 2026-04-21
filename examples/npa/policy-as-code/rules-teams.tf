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

    # private_apps expects a list of app name strings: ["app-one", "app-two"]
    # local.web_apps is already this format (see data.tf for how it's built)
    # Do NOT wrap names in extra brackets - ["[app-one]"] causes API errors
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

    # See data.tf for how local.database_apps is built from tags
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
