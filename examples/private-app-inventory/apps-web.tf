# =============================================================================
# Web Tier Applications
# =============================================================================
# Browser-accessible applications (Jira, Confluence, internal portals, etc.)
#
# Note: For https apps, real_host must be a FQDN (not an IP address)

resource "netskope_npa_private_app" "web" {
  for_each = var.web_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  private_app_protocol = "https"
  real_host            = each.value.real_host # Must be FQDN for https apps

  clientless_access  = each.value.clientless_access
  is_user_portal_app = false # Requires User Portal license
  use_publisher_dns  = true

  protocols = [
    {
      port     = each.value.port
      protocol = "tcp"
    }
  ]

  publishers = local.app_publishers

  tags = concat(
    local.common_tag_objects,
    local.env_tag,
    [{ tag_name = "web-tier" }],
    [for tag in each.value.tags : { tag_name = tag }]
  )
}
