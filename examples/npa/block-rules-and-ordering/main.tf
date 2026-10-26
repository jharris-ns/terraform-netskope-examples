# Block Rules and Rule Ordering Example
#
# Demonstrates the full lifecycle of NPA block rules and large-scale rule
# ordering. Covers scenarios from GitHub issues #74, #79, #106, #124, #125:
#
#   - Block rules with template display names (not .html filenames)
#   - In-place updates to block rules (emit_alert, user_groups, etc.)
#   - Blocking by user group and by device classification ("unmanaged")
#   - Allowing only managed devices ("managed" string value)
#   - netskope_npa_rules_order managing the full list position of all rules
#   - Removing a rule from rule_ids without re-PATCHing every other rule
#
# Provider >= 0.4.12 is required:
#   - 0.4.12 fixes block rule in-place updates (#124)
#   - 0.4.12 fixes npa_rules_order full-reshuffle on any change (#125)
#
# =============================================================================
# IMPORTANT NOTES
# =============================================================================
#
# 1. block_template must be the DISPLAY NAME shown in the Netskope UI:
#      Settings > Security Cloud Platform > NPA > Block Templates
#    e.g. "Generic Block" or "Private Apps Block Template"
#    Do NOT use the underlying filename (e.g. "5.html").
#    See README.md for behaviour when the templates API returns 403.
#
# 2. device_classification_id accepts both string and numeric values:
#      "managed"   — built-in managed device classification
#      "unmanaged" — built-in unmanaged device classification
#      "16715"     — numeric custom classification tag ID
#    String support was fixed in v0.4.9 (#74).
#
# 3. NPA uses most-specific-match, not top-to-bottom evaluation.
#    Rule list position is for organisational clarity only.
#    Use rule_order = { order = "bottom" } + lifecycle.ignore_changes on all
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
      version = ">= 0.4.12"
    }
  }
}

provider "netskope" {}

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
  is_user_portal_app      = true
}
