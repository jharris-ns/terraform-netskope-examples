# =============================================================================
# Admin/Infrastructure Access Rules
# =============================================================================
# These rules grant privileged access to admin groups.

# Admin SSH access to infrastructure
resource "netskope_npa_rules" "admin_ssh_access" {
  count = length(local.infrastructure_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-admin-ssh-access"
  description = "Allow admin groups SSH access to infrastructure"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Infrastructure apps only
    # IMPORTANT: Do NOT use brackets around app names - causes "Private app [[name]] doesn't exist" error
    private_apps = [for name in local.infrastructure_apps : name]

    # Admin groups
    user_groups = var.admin_groups

    # Client access only (SSH requires client)
    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order = "top"
  }
}

# Admin database access
resource "netskope_npa_rules" "admin_database_access" {
  count = length(local.database_apps) > 0 ? 1 : 0

  rule_name   = "${var.environment}-admin-database-access"
  description = "Allow admin and DBA groups access to databases"
  enabled     = "1"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # IMPORTANT: Do NOT use brackets around app names
    private_apps = [for name in local.database_apps : name]

    # Admin and DBA groups
    user_groups = concat(var.admin_groups, var.dba_groups)

    access_method = ["Client"]

    user_type = "user"
  }

  rule_order = {
    order = "top"
  }

  depends_on = [
    netskope_npa_rules.admin_ssh_access
  ]
}
