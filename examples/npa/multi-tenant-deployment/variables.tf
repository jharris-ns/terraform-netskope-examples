# =============================================================================
# Tenant (Subscription) Variables
# =============================================================================
# Keys must match the provider aliases and module call names in main.tf:
# tenant_a, tenant_b, tenant_c. Non-sensitive connection details and API keys
# are kept in two separate variables so plan output for var.tenants stays
# readable while credentials remain hidden.

variable "tenants" {
  description = "Per-tenant connection details, keyed by the tenant alias used in main.tf."
  type = map(object({
    server_url     = string # e.g. "https://tenant-a.goskope.com/api/v2"
    publisher_name = string # Must already exist in that tenant
  }))
}

variable "tenant_api_keys" {
  description = "Per-tenant API keys, keyed the same as var.tenants. Never commit real values — pass via TF_VAR_tenant_api_keys, a CI secret store, or an untracked terraform.tfvars."
  type        = map(string)
  sensitive   = true
}

# =============================================================================
# Application Catalog
# =============================================================================
# The single source of truth for every app across every tenant. Each app's
# `tenants` set decides which tenants it is deployed to — the root module
# filters this map per tenant before calling the child module.

variable "apps" {
  description = "Client-based private apps, keyed by private_app_name. `tenants` lists the tenant keys (from var.tenants) this app should be deployed to."
  type = map(object({
    hostname = string # NPA client hostname, e.g. "bastion.internal.company.com"
    port     = string # Port as a string, e.g. "22"
    protocol = optional(string, "tcp")
    tags     = optional(list(string), [])
    tenants  = set(string) # e.g. ["tenant_a", "tenant_b"]
  }))
}
