# =============================================================================
# Device Posture Rules (requires provider >= 0.4.2)
# =============================================================================
# These rules restrict access based on device classification tags.
# Tags are created in the Netskope UI: Settings > Device Classification.

# Allow access to sensitive apps only from devices with endpoint protection
resource "netskope_npa_rules" "require_endpoint_protection" {
  count = length(local.database_apps) > 0 && length(local.device_classification_tags) > 0 ? 1 : 0

  rule_name   = "${var.environment}-require-endpoint-protection"
  description = "Restrict database access to devices with approved endpoint protection"
  enabled     = "1"
  group_id    = local.default_group.id

  rule_data = {
    policy_type  = "private-app"
    json_version = 3

    match_criteria_action = {
      action_name = "allow"
    }

    private_apps = [for name in local.database_apps : name]

    user_groups = var.dba_groups

    access_method = ["Client"]

    # Only allow devices matching these classifications
    # device_classification_id expects strings; tostring() converts the integer IDs
    device_classification_id = [
      for tag_name in var.required_device_tags :
      tostring(local.device_tag_ids_by_name[tag_name])
      if contains(keys(local.device_tag_ids_by_name), tag_name)
    ]
  }

  # Place this before the general DBA rule for organizational clarity
  rule_order = {
    order = "before"
    rule_id = length(netskope_npa_rules.dba_readonly_access) > 0 ? (
      tonumber(netskope_npa_rules.dba_readonly_access[0].id)
    ) : null
  }

  depends_on = [netskope_npa_rules.developer_web_access]
}
