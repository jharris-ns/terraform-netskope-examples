# Policy and Rules Management Example
#
# This example demonstrates NPA policy configuration including:
# - Policy groups for organizing rules
# - Access rules with various conditions
# - DLP integration
# - Rule ordering and prioritization
#
# Use case: Implementing zero trust access policies for private applications

terraform {
  required_providers {
    netskope = {
      source = "netskopeoss/netskope"
    }
  }
}

provider "netskope" {}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Get existing policy groups
data "netskope_npa_policy_groups_list" "all" {}

# Get existing rules
data "netskope_npa_rules_list" "all" {}

# Get existing private apps
data "netskope_npa_private_apps_list" "all" {}

# =============================================================================
# POLICY GROUPS
# =============================================================================

# Create a policy group for engineering access
resource "netskope_npa_policy_groups" "engineering" {
  name = "Engineering Access Policies"
}

# Create a policy group for contractor access
resource "netskope_npa_policy_groups" "contractors" {
  name = "Contractor Access Policies"
}

# =============================================================================
# ACCESS RULES - ENGINEERING
# =============================================================================

# Rule 1: Allow engineering team full access to dev environments
resource "netskope_npa_rules" "engineering_dev_access" {
  rule_name   = "Engineering - Dev Environment Access"
  enabled     = "1"
  group_name  = netskope_npa_policy_groups.engineering.name
  description = "Allow engineering team to access development applications"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Apply to apps tagged with 'development'
    private_app_tags = ["development"]

    # Both client and browser access
    access_method = ["Client", "Clientless"]

    user_type   = "user"
    user_groups = ["Engineering"]
  }

  rule_order = {
    order = "top"
  }
}

# Rule 2: Engineering SSH access with periodic re-authentication
resource "netskope_npa_rules" "engineering_ssh_reauth" {
  rule_name   = "Engineering - SSH with Re-auth"
  enabled     = "1"
  group_name  = netskope_npa_policy_groups.engineering.name
  description = "Engineering SSH access requiring re-authentication every 4 hours"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Apply to apps tagged with 'ssh' or 'infrastructure'
    private_app_tags = ["ssh", "infrastructure"]

    access_method = ["Client"]

    user_type   = "user"
    user_groups = ["Engineering"]

    # Require re-authentication every 4 hours
    periodic_reauth = {
      reauth_interval      = "4"
      reauth_interval_unit = "hours"
    }
  }

  rule_order = {
    order   = "after"
    rule_id = tonumber(netskope_npa_rules.engineering_dev_access.id)
  }

  depends_on = [netskope_npa_rules.engineering_dev_access]
}

# =============================================================================
# ACCESS RULES - CONTRACTORS
# =============================================================================

# Rule 3: Contractors - Limited browser-only access
resource "netskope_npa_rules" "contractor_limited_access" {
  rule_name   = "Contractors - Browser Only Access"
  enabled     = "1"
  group_name  = netskope_npa_policy_groups.contractors.name
  description = "Contractors can only access approved apps via browser"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    # Only specific apps
    private_app_tags = ["contractor-approved"]

    # Browser only - no client access
    access_method = ["Clientless"]

    user_type   = "user"
    user_groups = ["Contractors"]

    # Re-authenticate every hour for contractors
    periodic_reauth = {
      reauth_interval      = "1"
      reauth_interval_unit = "hours"
    }
  }

  rule_order = {
    order = "bottom"
  }
}

# =============================================================================
# ACCESS RULES - SECURITY POLICIES
# =============================================================================

# Rule 4: Block access from specific countries
resource "netskope_npa_rules" "block_high_risk_countries" {
  rule_name   = "Security - Block High Risk Countries"
  enabled     = "1"
  description = "Block access from high-risk countries"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "block"
    }

    # Apply to all private apps (empty means all)
    private_apps = []

    access_method = ["Client", "Clientless"]

    user_type = "user"

    # Source country restrictions
    src_countries          = ["CN", "RU", "KP", "IR"]
    b_negate_src_countries = false
  }

  rule_order = {
    order = "top"
  }
}

# Rule 5: Default deny rule (catch-all at the end)
resource "netskope_npa_rules" "default_deny" {
  rule_name   = "Default - Deny All"
  enabled     = "1"
  description = "Default deny rule - blocks any access not explicitly allowed"

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "block"
    }

    # Apply to all users and all apps
    access_method = ["Client", "Clientless"]
    user_type     = "user"
  }

  rule_order = {
    order = "bottom"
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "policy_groups" {
  description = "Created policy groups"
  value = {
    engineering = {
      name = netskope_npa_policy_groups.engineering.name
    }
    contractors = {
      name = netskope_npa_policy_groups.contractors.name
    }
  }
}

output "rules_summary" {
  description = "Summary of created rules"
  value = [
    {
      name   = netskope_npa_rules.engineering_dev_access.rule_name
      action = "allow"
      group  = netskope_npa_policy_groups.engineering.name
    },
    {
      name   = netskope_npa_rules.engineering_ssh_reauth.rule_name
      action = "allow"
      group  = netskope_npa_policy_groups.engineering.name
    },
    {
      name   = netskope_npa_rules.contractor_limited_access.rule_name
      action = "allow"
      group  = netskope_npa_policy_groups.contractors.name
    },
    {
      name   = netskope_npa_rules.block_high_risk_countries.rule_name
      action = "block"
      group  = "Default"
    },
    {
      name   = netskope_npa_rules.default_deny.rule_name
      action = "block"
      group  = "Default"
    }
  ]
}

output "existing_rules_count" {
  description = "Number of existing rules in the tenant"
  value       = length(data.netskope_npa_rules_list.all.data)
}

output "existing_apps" {
  description = "List of existing private apps"
  value       = [for app in data.netskope_npa_private_apps_list.all.data : app.private_app_name]
}
