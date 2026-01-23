# =============================================================================
# Discover Existing Resources
# =============================================================================

data "netskope_npa_policy_groups_list" "all" {}

data "netskope_npa_private_apps_list" "all" {}

data "netskope_npa_rules_list" "all" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # Find the default policy group
  default_group = [
    for pg in data.netskope_npa_policy_groups_list.all.data :
    pg if pg.group_name == "Default"
  ][0]

  # Group apps by tags for easy reference in policy rules
  #
  # This pattern:
  # 1. Iterates through all private apps from the data source
  # 2. Extracts just the app NAME (string) - not the full app object
  # 3. Filters to apps that have at least one tag matching var.web_app_tags
  #
  # The result is a list of strings: ["app-one", "app-two", "app-three"]
  # This format is required by netskope_npa_rules - the API expects app names
  # as plain strings, not objects or nested arrays.
  #
  web_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if length([
      for tag in coalesce(app.tags, []) :
      tag if contains(var.web_app_tags, tag.tag_name)
    ]) > 0
  ]

  database_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if length([
      for tag in coalesce(app.tags, []) :
      tag if contains(var.database_app_tags, tag.tag_name)
    ]) > 0
  ]

  infrastructure_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if length([
      for tag in coalesce(app.tags, []) :
      tag if contains(var.infrastructure_app_tags, tag.tag_name)
    ]) > 0
  ]

  # All app names (for general rules)
  all_app_names = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
  ]

  # Portal apps (user_portal_app = true)
  portal_apps = [
    for app in data.netskope_npa_private_apps_list.all.private_apps :
    app.private_app_name
    if app.is_user_portal_app == true
  ]
}
