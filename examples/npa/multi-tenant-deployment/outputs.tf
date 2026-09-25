output "app_hostnames_by_tenant" {
  description = "Hostname of each app actually created, grouped by tenant — confirms which apps landed where"
  value = {
    tenant_a = module.tenant_a.app_hostnames
    tenant_b = module.tenant_b.app_hostnames
    tenant_c = module.tenant_c.app_hostnames
  }
}

output "deployment_matrix" {
  description = "Which tenants each app in the catalog targets (from var.apps), for a quick at-a-glance check against the plan"
  value       = { for k, a in var.apps : k => sort(tolist(a.tenants)) }
}

output "publisher_used_by_tenant" {
  description = "The publisher each tenant's apps were attached to"
  value = {
    tenant_a = module.tenant_a.publisher_used
    tenant_b = module.tenant_b.publisher_used
    tenant_c = module.tenant_c.publisher_used
  }
}
