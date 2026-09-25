# Multi-Tenant NPA Deployment Example
#
# This example demonstrates replicating NPA private apps across multiple
# Netskope tenants ("subscriptions") from a single Terraform configuration,
# where EACH APP chooses WHICH tenants it is deployed to.
#
# Default configuration (terraform.tfvars.example): 3 tenants, 3 apps, each
# app deployed to 2 of the 3 tenants:
#
#                  tenant_a   tenant_b   tenant_c
#   ssh-bastion       x          x
#   windows-rdp       x                     x
#   postgres-db                  x          x
#
# Use cases:
# - MSSPs / managed security providers running NPA for several customer tenants
# - Enterprises with separate Netskope tenants per business unit, region, or
#   subsidiary, where not every app belongs in every tenant
# - Promoting an app from a non-production tenant to production by adding one
#   tenant key to its `tenants` list
#
# =============================================================================
# THE PATTERN: CHILD MODULE + `providers` PASSING
# =============================================================================
#
# Each Netskope tenant is a fully separate REST API endpoint with its own
# credentials, so each needs its own aliased `provider "netskope"` block.
# Terraform does NOT support `for_each`/`count` on provider blocks, nor an
# expression in the `provider =` meta-argument, so the tenant list is static
# code. Everything else is data-driven:
#
#   1. modules/npa-apps/ defines the private app resource exactly ONCE.
#   2. The root module (this file) calls that module once per tenant and hands
#      each call its tenant's provider via `providers = { netskope = netskope.X }`.
#   3. Each module call filters the shared app catalog (var.apps) down to the
#      apps whose `tenants` set contains that tenant's key.
#
# This is HashiCorp's documented approach for deploying the same module across
# multiple accounts/regions:
# https://developer.hashicorp.com/terraform/language/meta-arguments/providers
# https://developer.hashicorp.com/terraform/language/modules/develop/providers
#
# Result: replicating an app to a different set of tenants is a one-line tfvars
# edit to its `tenants` list. Adding a tenant is one provider block + one
# module block below.
#
# =============================================================================
# IMPORTANT NOTES / GOTCHAS
# =============================================================================
#
# 1. Do NOT rely on the NETSKOPE_SERVER_URL / NETSKOPE_API_KEY environment
#    variables here. Those are only picked up by a single DEFAULT (unaliased)
#    provider configuration. Every aliased provider block below sets
#    server_url/api_key explicitly from variables instead.
#
# 2. Each tenant must already have at least one NPA publisher registered
#    (see npa/publisher-management). Publishers are tenant-scoped and cannot be
#    shared across tenants, so the module looks one up by name per tenant.
#
# 3. The keys in var.tenants / var.tenant_api_keys, the provider aliases, the
#    module call names, and the values used in each app's `tenants` set must
#    all agree (tenant_a / tenant_b / tenant_c). A typo in an app's `tenants`
#    entry does NOT error — the app is silently deployed nowhere for that key.
#
# 4. publisher_id must be tostring()-wrapped (handled inside the module).
#
# 5. This example manages private apps only. Policy rules referencing these
#    apps would follow the same per-tenant module pattern — see
#    npa/policy-as-code for rule syntax (plain-string app names, no brackets).
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.4"
    }
  }
}

# =============================================================================
# PROVIDER CONFIGURATION — one aliased provider block per tenant (static)
# =============================================================================

provider "netskope" {
  alias      = "tenant_a"
  server_url = var.tenants["tenant_a"].server_url
  api_key    = var.tenant_api_keys["tenant_a"]
}

provider "netskope" {
  alias      = "tenant_b"
  server_url = var.tenants["tenant_b"].server_url
  api_key    = var.tenant_api_keys["tenant_b"]
}

provider "netskope" {
  alias      = "tenant_c"
  server_url = var.tenants["tenant_c"].server_url
  api_key    = var.tenant_api_keys["tenant_c"]
}

# =============================================================================
# PER-TENANT APP SELECTION
# =============================================================================
# Build one filtered map per tenant from the shared catalog. An app appears in
# a tenant's map only if that tenant's key is in the app's `tenants` set.

locals {
  apps_tenant_a = { for k, a in var.apps : k => a if contains(a.tenants, "tenant_a") }
  apps_tenant_b = { for k, a in var.apps : k => a if contains(a.tenants, "tenant_b") }
  apps_tenant_c = { for k, a in var.apps : k => a if contains(a.tenants, "tenant_c") }
}

# =============================================================================
# MODULE CALLS — one per tenant, same module, different provider + app subset
# =============================================================================

module "tenant_a" {
  source = "./modules/npa-apps"

  providers = {
    netskope = netskope.tenant_a
  }

  apps           = local.apps_tenant_a
  publisher_name = var.tenants["tenant_a"].publisher_name
  tenant_tag     = "tenant-a"
}

module "tenant_b" {
  source = "./modules/npa-apps"

  providers = {
    netskope = netskope.tenant_b
  }

  apps           = local.apps_tenant_b
  publisher_name = var.tenants["tenant_b"].publisher_name
  tenant_tag     = "tenant-b"
}

module "tenant_c" {
  source = "./modules/npa-apps"

  providers = {
    netskope = netskope.tenant_c
  }

  apps           = local.apps_tenant_c
  publisher_name = var.tenants["tenant_c"].publisher_name
  tenant_tag     = "tenant-c"
}
