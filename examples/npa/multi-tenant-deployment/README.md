# Multi-Tenant NPA Deployment Example

Replicates NPA private applications across **multiple Netskope tenants**
("subscriptions") from a single Terraform configuration, where **each app
chooses which tenants it is deployed to**.

The default configuration has 3 tenants and 3 apps, each deployed to 2 of the 3:

|               | tenant_a | tenant_b | tenant_c |
|---------------|:--------:|:--------:|:--------:|
| `ssh-bastion` |    x     |    x     |          |
| `windows-rdp` |    x     |          |    x     |
| `postgres-db` |          |    x     |    x     |

## What This Creates

| Resource | Where | Key Fields |
|----------|-------|------------|
| `module.tenant_a` / `tenant_b` / `tenant_c` → `netskope_npa_private_app.this` | One module instance per tenant, `for_each` over that tenant's app subset | `providers = { netskope = netskope.tenant_x }` |

## Files

```
multi-tenant-deployment/
├── main.tf                    # 3 aliased providers, per-tenant app filtering, 3 module calls
├── variables.tf               # tenants, tenant_api_keys, apps (with per-app `tenants` set)
├── outputs.tf                 # hostnames by tenant, deployment matrix
├── terraform.tfvars.example
└── modules/
    └── npa-apps/              # Private app defined ONCE; receives its provider from the root
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## How It Works

Each Netskope tenant is a fully separate REST API endpoint with its own credentials, so each needs its own aliased `provider "netskope"` block. Terraform does not support `for_each`/`count` on provider blocks, nor an expression in a resource's `provider =` meta-argument, so the *list of tenants* is static code. Everything else is data:

1. **`modules/npa-apps/` defines the private app resource exactly once.** Inside the module the provider is just `netskope` — the module never knows which tenant it is talking to.
2. **The root module calls that module once per tenant**, handing each call its tenant's provider with the [`providers` meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/providers):

   ```hcl
   module "tenant_a" {
     source    = "./modules/npa-apps"
     providers = { netskope = netskope.tenant_a }
     apps      = local.apps_tenant_a
     # ...
   }
   ```

3. **Each module call receives a filtered slice of the shared app catalog.** An app's `tenants` set decides where it lands:

   ```hcl
   locals {
     apps_tenant_a = { for k, a in var.apps : k => a if contains(a.tenants, "tenant_a") }
   }
   ```

This is HashiCorp's documented pattern for deploying one module across multiple accounts or regions ([Providers within modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)). Replicating an app to a different set of tenants is a one-line edit to its `tenants` list in `terraform.tfvars`; the resource definition is never duplicated.

## Prerequisites

- A Netskope tenant with REST API v2 access for **each** tenant you want to manage
- At least one NPA publisher already registered in **each** tenant (see [`npa/publisher-management`](../publisher-management/)) — publishers are tenant-scoped and cannot be shared
- An API token per tenant (Settings > Tools > REST API v2)

## Usage

1. Copy the tfvars example and fill in your tenant details and app catalog:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Set API keys as a **sensitive** variable rather than committing them:

   ```bash
   export TF_VAR_tenant_api_keys='{"tenant_a":"...","tenant_b":"...","tenant_c":"..."}'
   ```

   Do **not** set `NETSKOPE_SERVER_URL` / `NETSKOPE_API_KEY` — those only apply to a single default (unaliased) provider and are ignored here.

3. Deploy:

   ```bash
   terraform init      # also initializes the local ./modules/npa-apps module
   terraform plan      # check the `deployment_matrix` output against your intent
   terraform apply
   ```

## Changing Where an App Is Deployed

Edit the app's `tenants` list in `terraform.tfvars` and re-apply. For example, to also roll `ssh-bastion` out to `tenant_c`:

```hcl
ssh-bastion = {
  hostname = "bastion.internal.company.com"
  port     = "22"
  tenants  = ["tenant_a", "tenant_b", "tenant_c"]   # was ["tenant_a", "tenant_b"]
}
```

Removing a tenant key from the list destroys that app in that tenant only.

## Adding a New Tenant

Adding `tenant_d` is two blocks in `main.tf` plus config — a Terraform language limitation (no dynamic provider blocks), not a Netskope one:

1. Add a `provider "netskope" { alias = "tenant_d" ... }` block
2. Add `apps_tenant_d` to the `locals` filter and a `module "tenant_d"` call (copy an existing one, change the alias and tag)
3. Add `tenant_d` to `var.tenants` and `var.tenant_api_keys`
4. Add `"tenant_d"` to the `tenants` list of any app that should exist there

The child module is untouched.

## Scaling Beyond a Handful of Tenants

This single-state pattern is clean up to roughly 5–10 tenants. Past that, consider:

- **One state per tenant** (Terraform CLI/HCP workspaces, or Terragrunt fan-out): one provider block, `var.tenant_key` selects credentials, and the catalog is filtered with `contains(a.tenants, var.tenant_key)`. Best blast-radius isolation — a bad apply affects one tenant.
- **[Terraform Stacks](https://developer.hashicorp.com/terraform/language/block/stack/tfcomponent/provider)** (HCP Terraform): component configurations *do* support `for_each` on provider blocks, so the tenant list becomes data too.

## Common Mistakes

| Mistake | Result |
|---------|--------|
| Relying on `NETSKOPE_SERVER_URL` / `NETSKOPE_API_KEY` env vars | Only the default (unaliased) provider reads them — aliased providers here fail to authenticate |
| Typo in an app's `tenants` entry (e.g. `"tenant-a"` instead of `"tenant_a"`) | No error — the app is silently deployed to no tenant for that key. Check the `deployment_matrix` output in `terraform plan` |
| Forgetting `providers = { ... }` on a module call | The module falls back to the implied empty default provider and fails to authenticate |
| Declaring a `provider` block inside `modules/npa-apps/` | Breaks provider passing; HashiCorp [recommends against](https://developer.hashicorp.com/terraform/language/block/provider#background) provider blocks in child modules |
| `publisher_name` in `var.tenants` not matching an existing publisher in that tenant | The `[0]` in the module's publisher lookup errors with "index out of range" |
| Committing real API keys in `terraform.tfvars` | Credential leak — use `TF_VAR_tenant_api_keys`, a secrets manager, or your CI/CD secret store |

## Outputs

| Output | Description |
|--------|-------------|
| `app_hostnames_by_tenant` | Hostname of each app actually created, grouped by tenant |
| `deployment_matrix` | Each catalog app → the tenants it targets (from `var.apps`) |
| `publisher_used_by_tenant` | Publisher each tenant's apps were attached to |

## Cleanup

```bash
terraform destroy
```

## References

- [`providers` meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/providers) — Terraform docs
- [Providers within modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers) — Terraform docs
- [Provider block reference: alias](https://developer.hashicorp.com/terraform/language/block/provider#alias) — Terraform docs
- [Using count or for_each in Provider Configuration](https://support.hashicorp.com/hc/en-us/articles/6304194229267-Using-count-or-for-each-in-Provider-Configuration) — HashiCorp Help Center (why provider blocks cannot be dynamic)
- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs) — `server_url` / `api_key` / `tenant` provider arguments
- [`docs/npa-app-and-policy-management.md`](../../../docs/npa-app-and-policy-management.md) — private app attribute reference
- [`npa/client-app`](../client-app/) — the single-tenant client-based app pattern this example replicates
