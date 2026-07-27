# RBAC Roles

Version-control your Netskope admin role definitions so that role changes are auditable, reviewable, and reproducible across tenants.

**Difficulty:** Simple
**Provider version:** >= 0.4.8

## Overview

RBAC roles control which API groups an admin can access and at what permission level (`none` / `r` / `rw` / `rwa`). Before this resource existed, roles had to be created and updated in the Netskope UI — making them invisible to IaC workflows and impossible to diff or review.

Only custom roles (`type = 0`) can be managed via Terraform. Predefined (system) roles are read-only and are accessible via the data source.

## Quick Start

```bash
cd examples/npa/rbac-roles

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan
```

> **Before applying:** Update the `api_group_id` values in `main.tf` to match your tenant. See [Finding API Group IDs](#finding-api-group-ids) below.

## What This Creates

- A **Security Auditor** role — read-only access across NPA and URL lists
- An **NPA Operator** role — read-write access to NPA resources, restricted to corporate IP ranges via `ip_allow_list`

## Finding API Group IDs

API group IDs are integers that vary slightly between tenants. Retrieve yours with:

```bash
curl -s \
  -H "Netskope-Api-Token: $NETSKOPE_API_KEY" \
  "$NETSKOPE_SERVER_URL/rbac/roles/config" \
  | jq '.apiGroups[] | {id: .apiGroupId, name: .apiGroupName, displayName: .displayName}'
```

Use the returned IDs in your `api_groups` block.

## Key Patterns

### Create a Role with API Group Permissions

```hcl
resource "netskope_rbac_role" "auditor" {
  name        = "Security Auditor"
  description = "Read-only access for security auditors."

  api_groups = [
    { api_group_id = 1,   permission = "r" },  # NPA private apps
    { api_group_id = 107, permission = "r" },  # RBAC roles
  ]
}
```

### Restrict a Role to Corporate IPs

```hcl
resource "netskope_rbac_role" "operator" {
  name        = "NPA Operator"
  description = "Read-write NPA access, corporate network only."

  api_groups = [
    { api_group_id = 1, permission = "rw" },
    { api_group_id = 2, permission = "rw" },
  ]

  ip_allow_list = {
    enable_ip_allow_list = true
    ip_list              = ["10.0.0.0/8", "192.168.0.0/16"]
  }
}
```

### Look Up All Roles

```hcl
data "netskope_rbac_role_list" "all" {}

output "roles" {
  value = [for r in data.netskope_rbac_role_list.all.roles : {
    id   = r.role_id
    name = r.name
  }]
}
```

## Permission Levels

| Permission | Access |
|------------|--------|
| `none` | No access |
| `r` | Read-only |
| `rw` | Read and write |
| `rwa` | Read, write, and admin actions |

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| Wrong `api_group_id` | Role created but affects wrong API group | Query `/rbac/roles/config` to get correct IDs |
| Delete role assigned to users | API returns 409 | Unassign users from the role first |
| Modify predefined role | API returns 400 | Only custom roles are writable |
| Missing required `api_groups` | API returns 400 | At least one api_group entry is required |

## Cleanup

```bash
terraform destroy
```

Destroy will fail if users are still assigned to either role. Remove user assignments in the Netskope UI first.

## Related Examples

- [rbac-labels/](../rbac-labels/) — Label-based resource access control
- [policy-as-code/](../policy-as-code/) — NPA access policy rules
