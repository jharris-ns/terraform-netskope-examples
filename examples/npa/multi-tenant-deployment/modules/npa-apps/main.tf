# npa-apps child module
#
# Defines the private app resource ONCE. The root module calls this module once
# per tenant and hands each call that tenant's aliased provider via the
# `providers = { netskope = netskope.<alias> }` meta-argument. Inside this
# module the provider is simply "netskope" — the module never knows or cares
# which tenant it is talking to.
#
# Per HashiCorp guidance, child modules must NOT declare `provider` blocks;
# they only declare the provider requirement and receive the configuration
# from the root module:
# https://developer.hashicorp.com/terraform/language/modules/develop/providers

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
# PUBLISHER LOOKUP — scoped to whichever tenant this module instance targets
# =============================================================================

data "netskope_npa_publishers_list" "all" {}

locals {
  publisher = [
    for p in data.netskope_npa_publishers_list.all.data.publishers :
    p if p.publisher_name == var.publisher_name
  ][0]
}

# =============================================================================
# PRIVATE APPS — one resource block, for_each over the apps this tenant gets
# =============================================================================
# The root module has already filtered var.apps down to only the apps whose
# `tenants` list includes this tenant, so a plain for_each is all that is
# needed here. Client-based apps are used (see npa/client-app) to keep the
# multi-tenant pattern itself the focus of this example.

resource "netskope_npa_private_app" "this" {
  for_each = var.apps

  private_app_name     = each.key
  private_app_hostname = each.value.hostname

  # Client-based apps: clientless_access must be false (default)
  clientless_access  = false
  is_user_portal_app = false
  use_publisher_dns  = true

  protocols = [
    {
      port     = each.value.port
      protocol = each.value.protocol
    }
  ]

  publishers = [
    {
      # tostring() required — the API returns publisher_id as a number but the
      # publishers block expects a string
      publisher_id   = tostring(local.publisher.publisher_id)
      publisher_name = local.publisher.publisher_name
    }
  ]

  tags = concat(
    [
      { tag_name = "managed-by-terraform" },
      { tag_name = var.tenant_tag },
    ],
    [for t in each.value.tags : { tag_name = t }]
  )
}
