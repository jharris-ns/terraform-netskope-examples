# RBAC Labels for NPA Resources

Implement Label-Based Access Control (LBAC) to separate management of NPA resources by team, environment, or region.

**Difficulty:** Simple
**Provider version:** >= 0.4.0

## Overview

RBAC labels let you scope administrative access to specific resources. When labels are assigned to private apps, publishers, or local brokers, only administrators with matching label scopes can view or manage those resources.

Labels support hierarchy up to 4 levels (e.g., Company > Department > Team > Project).

## Quick Start

```bash
cd examples/npa/rbac-labels

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan
```

## What This Creates

- A top-level RBAC label (department)
- Two child labels (production, staging)
- Two private apps, each tagged with the appropriate environment label
- Discovers all labels via the list data source

## Label Hierarchy

```
Engineering (#0294C9)
  +-- Engineering-Production (#FF5733)
  +-- Engineering-Staging (#FFC300)
```

## Key Patterns

### Create a Label Hierarchy

```hcl
resource "netskope_rbac_label" "parent" {
  name  = "Engineering"
  color = "#0294C9"
}

resource "netskope_rbac_label" "child" {
  name      = "Engineering-Production"
  parent_id = netskope_rbac_label.parent.label_id
  color     = "#FF5733"
}
```

### Assign Labels to Resources

```hcl
resource "netskope_npa_private_app" "app" {
  # ... app config ...
  label_ids = [netskope_rbac_label.child.label_id]
}
```

### Discover Existing Labels

```hcl
data "netskope_rbac_label_list" "all" {}

output "labels" {
  value = [for l in data.netskope_rbac_label_list.all.labels : {
    id   = l.label_id
    name = l.name
  }]
}
```

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| Hierarchy > 4 levels | API rejects | Flatten your label structure |
| Delete label in use by roles | API error | Remove label from roles first |
| Duplicate label names | API error | Use unique names at each level |

## Cleanup

```bash
terraform destroy
```

**Note:** Labels assigned to admin roles must be unassigned before deletion.

## Related Examples

- [private-app-inventory](../private-app-inventory/) - Manage multiple apps with tags
- [policy-as-code](../policy-as-code/) - Access policies
