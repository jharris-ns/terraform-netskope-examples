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

  # Group apps by tags for easy reference
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
