# =============================================================================
# Netskope Publisher Resources
# =============================================================================

resource "netskope_npa_publisher" "this" {
  publisher_name = var.publisher_name
}

resource "netskope_npa_publisher_token" "this" {
  publisher_id = netskope_npa_publisher.this.publisher_id
}
