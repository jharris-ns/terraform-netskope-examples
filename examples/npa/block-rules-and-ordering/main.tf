# Block Rules and Rule Ordering Example
#
# Demonstrates the full lifecycle of NPA block rules and rule ordering:
#
#   - Block rules with template display names (not .html filenames)
#   - In-place updates to block rules (emit_alert, user_groups, etc.)
#   - Blocking by user group and by device classification ("unmanaged")
#   - Allowing only managed devices ("managed" string value)
#   - netskope_npa_rules_order owning the list position of all rules
#
# Provider >= 0.4.13 is required. Earlier releases failed block-rule updates
# (#124), moved rules to the bottom on every update (#129), and showed a
# template diff on every Terraform Cloud run (#79, #105, #129).
#
# =============================================================================
# IMPORTANT NOTES
# =============================================================================
#
# 1. block_template must be the DISPLAY NAME shown in the Netskope UI:
#      Settings > Security Cloud Platform > NPA > Block Templates
#    e.g. "Generic Block" or "Private Apps Block Template"
#    Do NOT use the underlying filename (e.g. "block_page.html").
#    Expect ONE "block_page.html" -> "<name>" diff on the first plan after
#    create or import; apply it, then plans are empty. See README.md.
#
# 2. Two separate fields control device classification:
#      classification           — built-in states: "managed" or "unmanaged"
#      device_classification_id — numeric custom tag IDs only (e.g. ["16715"])
#    Do NOT put "managed"/"unmanaged" in device_classification_id — the
#    provider converts that list to integers and rejects non-numeric values
#    (provider issue #74). Use classification instead.
#
# 3. NPA uses most-specific-match, not top-to-bottom evaluation.
#    Rule list position is for organisational clarity only.
#    rule_order sets the position on CREATE only; the provider does not send it
#    on update. Use rule_order = { order = "bottom" } + ignore_changes on all
#    rules, and control final positions via netskope_npa_rules_order.
#
# 4. Import existing UI-created block rules with:
#      terraform import netskope_npa_rules.block_users <rule_id>
#    See README.md for the expected first-plan behaviour.
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

# ---------------------------------------------------------------------------
# Policy group
# ---------------------------------------------------------------------------
# Look up all groups and pick the one matching var.policy_group_name,
# or fall back to the built-in "Default" group.
data "netskope_npa_policy_groups_list" "all" {}

locals {
  policy_group = var.policy_group_name != null ? (
    [for pg in data.netskope_npa_policy_groups_list.all.data : pg
    if pg.group_name == var.policy_group_name][0]
    ) : (
    [for pg in data.netskope_npa_policy_groups_list.all.data : pg
    if pg.group_name == "Default"][0]
  )
}

# ---------------------------------------------------------------------------
# Publisher
# ---------------------------------------------------------------------------

resource "netskope_npa_publisher" "main" {
  publisher_name = "${var.environment}-block-example-publisher"
}

# ---------------------------------------------------------------------------
# Private apps
# ---------------------------------------------------------------------------

# Client app — accessed via NPA Client
resource "netskope_npa_private_app" "internal_api" {
  private_app_name     = "${var.environment}-internal-api"
  private_app_hostname = "api.internal.example.com"

  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(netskope_npa_publisher.main.publisher_id)
      publisher_name = netskope_npa_publisher.main.publisher_name
    }
  ]

  use_publisher_dns       = true
  trust_self_signed_certs = false
}

# Clientless app — accessed via browser (no NPA Client required)
resource "netskope_npa_private_app" "internal_portal" {
  private_app_name     = "${var.environment}-internal-portal"
  private_app_hostname = "portal.internal.example.com"

  protocols = [
    {
      port     = "443"
      protocol = "tcp"
    }
  ]

  publishers = [
    {
      publisher_id   = tostring(netskope_npa_publisher.main.publisher_id)
      publisher_name = netskope_npa_publisher.main.publisher_name
    }
  ]

  use_publisher_dns       = true
  trust_self_signed_certs = false
  clientless_access       = true
}
