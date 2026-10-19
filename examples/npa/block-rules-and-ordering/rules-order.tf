# =============================================================================
# Rule Ordering — requires provider >= 0.4.12
# =============================================================================
#
# netskope_npa_rules_order controls the LIST POSITION of rules in the Netskope
# UI and API response. NPA uses most-specific-match evaluation, not
# top-to-bottom, so list position affects display and auditing — not which rule
# is enforced.
#
# ----- The recommended pattern (issue #125) ---------------------------------
#
# Each rule resource:
#   rule_order = { order = "bottom" }     — places the rule at the bottom on
#                                           create, away from live traffic
#   lifecycle.ignore_changes = [rule_order] — stops Terraform re-sending the
#                                              rule_order field on every update
#
# This single resource then owns the final list position for all rules.
#
# ----- Fixed in v0.4.12 (issue #125) ----------------------------------------
#
# In v0.4.11, any change to rule_ids (adding, removing, or reordering even
# one ID) caused the provider to PATCH every managed rule to "top" serially —
# O(n) API calls. With ~200 rules this took 4+ minutes and left the live list
# visibly scrambled mid-apply.
#
# v0.4.12 reads the live order first and only moves rules that are actually
# out of place. Removing one ID from a list of 200 rules that are already in
# the right relative order sends zero PATCHes.
#
# ----- Removing a rule ------------------------------------------------------
#
# 1. Remove the rule resource from rules-block.tf / rules-allow.tf.
# 2. Remove its ID reference from local.ordered_rule_ids below.
# 3. terraform apply — the rule resource is destroyed, and npa_rules_order
#    sends zero PATCHes for the remaining rules (they were already in order).
#
# ----- Adding a rule --------------------------------------------------------
#
# 1. Add the rule resource with rule_order = { order = "bottom" }.
# 2. Add its ID reference at the desired position in local.ordered_rule_ids.
# 3. terraform apply — the new rule is created, then positioned by this resource.
#    Only the rules that need to move to accommodate the new position are PATCHed.
#
# =============================================================================

locals {
  # All rule IDs in the desired display order.
  # compact() drops nulls produced by count = 0 resources.
  #
  # Recommended order: block rules at the top, allow rules below.
  # Block rules appear first in the Netskope UI for operational visibility.
  ordered_rule_ids = compact([
    # --- Block rules (top of list) ---
    length(netskope_npa_rules.block_users) > 0
    ? netskope_npa_rules.block_users[0].id : null,
    netskope_npa_rules.block_unmanaged_devices.id,

    # --- Allow rules (below block rules) ---
    length(netskope_npa_rules.allow_admins) > 0
    ? netskope_npa_rules.allow_admins[0].id : null,
    netskope_npa_rules.allow_managed_devices.id,
    netskope_npa_rules.allow_all_clientless.id,
  ])
}

resource "netskope_npa_rules_order" "main" {
  rule_ids = local.ordered_rule_ids
}
