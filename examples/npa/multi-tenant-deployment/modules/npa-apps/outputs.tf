output "app_hostnames" {
  description = "private_app_hostname of each app created in this tenant, keyed by app name"
  value       = { for k, a in netskope_npa_private_app.this : k => a.private_app_hostname }
}

output "publisher_used" {
  description = "The publisher the apps in this tenant were attached to"
  value       = local.publisher.publisher_name
}
