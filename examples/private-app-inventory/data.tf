# =============================================================================
# Data Sources - Discover Existing Resources
# =============================================================================

data "netskope_npa_publishers_list" "all" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # ---------------------------------------------------------------------------
  # Publisher Lookup
  # ---------------------------------------------------------------------------
  # Pattern: Find a resource by name from a data source list
  #
  # The for-expression filters the list: [for item in list : item if condition]
  # The [0] at the end extracts the single matching item from the result
  #
  # Note: This will fail if no publisher matches - ensure the name exists
  #
  primary_publisher = [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.primary_publisher_name
  ][0]

  # Pattern: Optional resource lookup with ternary
  #
  # If secondary_publisher_name is empty string, set to null (no secondary)
  # Otherwise, look it up the same way as primary
  #
  secondary_publisher = var.secondary_publisher_name != "" ? [
    for pub in data.netskope_npa_publishers_list.all.data.publishers :
    pub if pub.publisher_name == var.secondary_publisher_name
  ][0] : null

  # ---------------------------------------------------------------------------
  # Publisher List for App Assignment
  # ---------------------------------------------------------------------------
  # Pattern: Build a list of objects for the publishers attribute
  #
  # Private apps require publishers as a list of objects with specific keys:
  #   { publisher_id = "string", publisher_name = "string" }
  #
  # Note: publisher_id must be a string (use tostring() to convert from number)
  #
  # This builds either a single-publisher or dual-publisher list based on config
  #
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

  # ---------------------------------------------------------------------------
  # Tag Formatting
  # ---------------------------------------------------------------------------
  # Pattern: Convert simple strings to tag objects
  #
  # The Netskope API expects tags as: [{ tag_name = "value" }, { tag_name = "value2" }]
  # This converts a simple list ["tag1", "tag2"] to the required format
  #
  common_tag_objects = [
    for tag in var.common_tags : { tag_name = tag }
  ]

  # Single tag as a list (for use with concat)
  env_tag = [{ tag_name = var.environment }]
}
