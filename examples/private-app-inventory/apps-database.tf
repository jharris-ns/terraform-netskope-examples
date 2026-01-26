# =============================================================================
# Database Tier Applications
# =============================================================================
# Database connections (PostgreSQL, MySQL, MongoDB, etc.)

resource "netskope_npa_private_app" "database" {
  for_each = var.database_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  private_app_protocol = "tcp"
  real_host            = each.value.real_host

  clientless_access  = false
  is_user_portal_app = false
  use_publisher_dns  = true

  # Note: If adding multiple protocols to any app, list them in ascending port
  # order to avoid Terraform drift. The API may return protocols in a different
  # order, causing plan changes if not sorted.
  protocols = [
    {
      port     = each.value.port
      protocol = each.value.protocol
    }
  ]

  publishers = local.app_publishers

  tags = concat(
    local.common_tag_objects,
    local.env_tag,
    [{ tag_name = "database-tier" }],
    [for tag in each.value.tags : { tag_name = tag }]
  )
}
