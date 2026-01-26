output "rule_summary" {
  description = "Summary of created rules"
  value = {
    admin_ssh_access_created       = length(netskope_npa_rules.admin_ssh_access) > 0
    admin_database_access_created  = length(netskope_npa_rules.admin_database_access) > 0
    developer_web_access_created   = length(netskope_npa_rules.developer_web_access) > 0
    dba_database_access_created    = length(netskope_npa_rules.dba_readonly_access) > 0
    general_browser_access_created = length(netskope_npa_rules.general_browser_access) > 0
  }
}

output "apps_by_category" {
  description = "Applications grouped by category"
  value = {
    web_apps            = local.web_apps
    database_apps       = local.database_apps
    infrastructure_apps = local.infrastructure_apps
    portal_apps         = local.portal_apps
  }
}
