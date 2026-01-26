# =============================================================================
# Infrastructure Applications
# =============================================================================
# SSH, RDP, and other infrastructure access
#
# Note: real_host must be a single IP or FQDN (CIDR ranges not supported)

locals {
  # ---------------------------------------------------------------------------
  # Protocol Lookup Map
  # ---------------------------------------------------------------------------
  # Pattern: Use a map for value translation
  #
  # Maps let you translate user-friendly values to API-required values.
  # Used with lookup(): lookup(map, key, default)
  #
  # Example: lookup(local.infra_protocols, "ssh", "tcp") returns "ssh"
  # Example: lookup(local.infra_protocols, "unknown", "tcp") returns "tcp" (default)
  #
  # This makes variable input cleaner - users specify "ssh" and we handle the rest
  #
  infra_protocols = {
    ssh = "ssh"
    rdp = "rdp"
    vnc = "vnc"
  }
}

resource "netskope_npa_private_app" "infra" {
  for_each = var.infra_apps

  private_app_name     = "${var.environment}-${each.key}"
  private_app_hostname = each.value.hostname
  private_app_protocol = lookup(local.infra_protocols, each.value.app_type, "tcp")
  real_host            = each.value.real_host # Single IP or FQDN only

  clientless_access  = true # Required for SSH/RDP/VNC access
  is_user_portal_app = false
  use_publisher_dns  = true

  # Note: If adding multiple protocols to any app, list them in ascending port
  # order to avoid Terraform drift. The API may return protocols in a different
  # order, causing plan changes if not sorted. See provider documentation for details.
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
    [{ tag_name = "infrastructure" }],
    [{ tag_name = each.value.app_type }],
    [for tag in each.value.tags : { tag_name = tag }]
  )
}
