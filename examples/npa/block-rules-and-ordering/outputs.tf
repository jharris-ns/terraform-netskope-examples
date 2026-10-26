output "publisher_id" {
  description = "ID of the NPA publisher created by this example."
  value       = netskope_npa_publisher.main.publisher_id
}

output "private_app_ids" {
  description = "IDs of the private apps created by this example."
  value = {
    internal_api    = netskope_npa_private_app.internal_api.id
    internal_portal = netskope_npa_private_app.internal_portal.id
  }
}

output "block_rule_ids" {
  description = "IDs of the block rules managed by this example (non-null values only)."
  value = compact([
    length(netskope_npa_rules.block_users) > 0
    ? netskope_npa_rules.block_users[0].id : null,
    netskope_npa_rules.block_unmanaged_devices.id,
  ])
}

output "allow_rule_ids" {
  description = "IDs of the allow rules managed by this example (non-null values only)."
  value = compact([
    length(netskope_npa_rules.allow_admins) > 0
    ? netskope_npa_rules.allow_admins[0].id : null,
    netskope_npa_rules.allow_managed_devices.id,
    netskope_npa_rules.allow_all_clientless.id,
  ])
}

output "rule_order_id" {
  description = "ID of the npa_rules_order resource that controls list positions."
  value       = netskope_npa_rules_order.main.id
}

output "ordered_rule_ids" {
  description = "Rule IDs in the order managed by netskope_npa_rules_order."
  value       = local.ordered_rule_ids
}
