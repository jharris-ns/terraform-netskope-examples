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
#    Rule position in the list is organizational only.
#    rule_order sets the position on CREATE only (the provider never sends it
#    on update). Every rule here uses rule_order = { order = "bottom" } plus
#    lifecycle.ignore_changes; netskope_npa_rules_order in rules-order.tf owns
#    the final list order.
#
# 4. Block rules: template must be the DISPLAY NAME from the Netskope UI.
#    Expect ONE "block_page.html" -> "<name>" diff on the first plan after
#    create or import; apply it, then plans are empty. See rules-deny.tf.
#
# 5. netskope_npa_policy_groups.group_order works on create only. Changing it
#    after creation currently fails with a backend error (provider issue #110).
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.4.13"
    }
  }
}

provider "netskope" {}
