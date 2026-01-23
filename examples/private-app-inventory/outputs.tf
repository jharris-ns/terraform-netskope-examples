# =============================================================================
# Outputs
# =============================================================================

output "web_apps" {
  description = "Created web tier applications"
  value = {
    for name, app in netskope_npa_private_app.web : name => {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
      url      = "https://${app.private_app_hostname}"
    }
  }
}

output "database_apps" {
  description = "Created database tier applications"
  value = {
    for name, app in netskope_npa_private_app.database : name => {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
      port     = app.protocols[0].port
    }
  }
}

output "infra_apps" {
  description = "Created infrastructure applications"
  value = {
    for name, app in netskope_npa_private_app.infra : name => {
      id       = app.private_app_id
      name     = app.private_app_name
      hostname = app.private_app_hostname
      port     = app.protocols[0].port
    }
  }
}

output "summary" {
  description = "Summary of created applications"
  value = {
    environment     = var.environment
    web_app_count   = length(netskope_npa_private_app.web)
    db_app_count    = length(netskope_npa_private_app.database)
    infra_app_count = length(netskope_npa_private_app.infra)
    total_apps = (
      length(netskope_npa_private_app.web) +
      length(netskope_npa_private_app.database) +
      length(netskope_npa_private_app.infra)
    )
  }
}
