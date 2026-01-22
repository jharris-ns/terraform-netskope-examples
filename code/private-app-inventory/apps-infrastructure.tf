# =============================================================================
# Infrastructure Applications
# =============================================================================
# SSH, RDP, and other infrastructure access
#
# Note: real_host must be a single IP or FQDN (CIDR ranges not supported)

locals {
  # Map app_type to protocol settings
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
