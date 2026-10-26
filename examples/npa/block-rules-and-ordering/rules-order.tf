# =============================================================================
# Rule Ordering — requires provider >= 0.4.13
# =============================================================================
#
# netskope_npa_rules_order controls the LIST POSITION of rules in the Netskope
# UI and API response. NPA uses most-specific-match evaluation, not
# top-to-bottom, so list position affects display and auditing — not which rule
# is enforced.
#
# ----- The pattern ----------------------------------------------------------
#
# Each rule resource:
#   rule_order = { order = "bottom" }       — places the rule at the bottom on
#                                             CREATE, away from live traffic.
#                                             The provider never sends rule_order
#                                             on update (since 0.4.13), so a rule
#                                             keeps its position when edited.
#   lifecycle.ignore_changes = [rule_order] — a later edit of rule_order in
#                                             config would otherwise show a diff
#                                             that applies without effect.
#
# This single resource then owns the final list position for all rules. It
# reads the live order first and only moves rules that are out of place
# (#125, fixed in 0.4.12); removing one ID from a correctly ordered list sends
# zero PATCHes.
#
# ----- Removing a rule ------------------------------------------------------
#
# 1. Remove the rule resource from rules-block.tf / rules-allow.tf.
# 2. Remove its ID reference from local.ordered_rule_ids below.
# 3. terraform apply.
#
# ----- Adding a rule --------------------------------------------------------
#
# 1. Add the rule resource with rule_order = { order = "bottom" }.
# 2. Add its ID reference at the desired position in local.ordered_rule_ids.
# 3. terraform apply — the new rule is created, then positioned by this resource.
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
