# =============================================================================
# Data Sources - Discover Existing Resources
# =============================================================================

data "netskope_npa_publishers_list" "all" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # Find publishers by name
  primary_publisher = [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.primary_publisher_name
  ][0]

  secondary_publisher = var.secondary_publisher_name != "" ? [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.secondary_publisher_name
  ][0] : null

  # Build publisher list for apps
  app_publishers = var.secondary_publisher_name != "" ? [
    {
      publisher_id   = tostring(local.primary_publisher.publisher_id)
      publisher_name = local.primary_publisher.publisher_name
    },
    {
      publisher_id   = tostring(local.secondary_publisher.publisher_id)
      publisher_name = local.secondary_publisher.publisher_name
    }
  ] : [
    {
      publisher_id   = tostring(local.primary_publisher.publisher_id)
      publisher_name = local.primary_publisher.publisher_name
    }
  ]

  # Common tags as objects
  common_tag_objects = [
    for tag in var.common_tags : { tag_name = tag }
  ]

  # Environment tag
  env_tag = [{ tag_name = var.environment }]
}
