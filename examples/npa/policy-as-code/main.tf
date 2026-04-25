# Policy-as-Code Example
#
# This example demonstrates how to implement NPA access policies using Terraform,
# organizing rules by team and access level.
#
# =============================================================================
# IMPORTANT NOTES:
# =============================================================================
#
# 1. Private app names in rules must NOT have brackets
#    WRONG: private_apps = [for name in apps : "[${name}]"]  (creates [[name]])
#    RIGHT: private_apps = [for name in apps : name]         (plain string)
#    Error: "Private app [[name]] doesn't exist"
#
# 2. User groups must match EXACTLY what comes from your IdP
#    The user_groups values must be valid groups that exist in your Netskope tenant
#    Error: "Invalid values from users, userGroups"
#    Solution: Set group variables to empty [] if not using group-based rules
#
# 3. NPA rules use most-specific-match evaluation, not top-to-bottom
#    Rule position in the list is organizational only
#    Use rule_order to control list placement for readability
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.4"
    }
  }
}

provider "netskope" {}
