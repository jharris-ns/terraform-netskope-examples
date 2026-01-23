# Policy as Code with NPA Rules

Manage Netskope NPA access policies using Terraform. This example shows how to create policy groups, define access rules, manage rule ordering, and implement role-based access patterns.

**Difficulty:** Intermediate

## Quick Start

```bash
cd examples/policy-as-code
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your IdP group names and app tags

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan && terraform apply
```

## What This Creates

- Deny rules for blocked users (evaluated first)
- Admin access rules for infrastructure and databases
- Developer access rules for web applications
- DBA access rules for databases
- General browser access for portal apps
- Catch-all deny rule (deny-by-default)

## NPA Policy Hierarchy

```
+-------------------------------------------------+
|               Policy Groups                      |
|  +-------------------------------------------+  |
|  |  Default Group (ID: 1)                    |  |
|  |  +-------------------------------------+  |  |
|  |  |  Rule 1: Deny-Blocked-Users         |  |  |
|  |  |  Rule 2: Allow-Admin-SSH            |  |  |
|  |  |  Rule 3: Allow-Dev-Web-Apps         |  |  |
|  |  |  Rule 4: Allow-All-Browser-Apps     |  |  |
|  |  +-------------------------------------+  |  |
|  +-------------------------------------------+  |
+-------------------------------------------------+
```

Rules are evaluated top-to-bottom. First matching rule wins.

## Rule Evaluation Order

```
1. Deny blocked users     <- First (always deny terminated/quarantined)
2. Admin SSH access       <- Privileged access
3. Admin database access
4. Developer web access   <- Team-based access
5. DBA database access
6. General browser access <- Broad access
7. Deny all other         <- Last (catch-all deny)
```

## Prerequisites

- Private applications already created with appropriate tags (see [private-app-inventory](../private-app-inventory/))
- User groups configured in your IdP
- IdP groups synced to Netskope
- Terraform 1.0+ installed

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration |
| `variables.tf` | User groups and app tags |
| `data.tf` | Discover existing apps and policy groups |
| `rules-deny.tf` | Deny rules (blocked users) |
| `rules-admin.tf` | Admin/privileged access rules |
| `rules-teams.tf` | Team-based access rules |
| `rules-general.tf` | General access and catch-all |
| `outputs.tf` | Rule order and app categories |

## How It Works

### Dynamic App Selection by Tags

The example uses locals to dynamically group apps by their tags. See `data.tf`:

```hcl
# Pattern: Filter list by nested attribute
# See: getting-started/terraform-basics.md for pattern details
web_apps = [
  for app in data.netskope_npa_private_apps_list.all.private_apps :
  app.private_app_name
  if length([
    for tag in coalesce(app.tags, []) :
    tag if contains(var.web_app_tags, tag.tag_name)
  ]) > 0
]
```

This:
1. Iterates through all private apps
2. Extracts just the app NAME (string)
3. Filters to apps with matching tags
4. Result: `["app-one", "app-two"]` - the format required by rules

### Conditional Resource Creation

Rules only get created if matching apps exist:

```hcl
# Pattern: Conditional count
# See: getting-started/terraform-basics.md for pattern details
resource "netskope_npa_rules" "developer_web_access" {
  count = length(local.web_apps) > 0 ? 1 : 0
  # ...
}
```

### Rule Ordering with depends_on

Rules are ordered using `rule_order` and `depends_on`:

```hcl
resource "netskope_npa_rules" "rule_2" {
  rule_order = {
    order   = "after"
    rule_id = tonumber(netskope_npa_rules.rule_1.id)
  }

  depends_on = [netskope_npa_rules.rule_1]
}
```

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| `enabled = true` | Type error | Use string: `enabled = "1"` |
| `enabled = 1` | Type error | Use string: `enabled = "1"` |
| Missing `depends_on` | Rules created in wrong order | Add `depends_on` chain |
| Deny rule at bottom | Deny never matches | Use `rule_order = { order = "top" }` |
| Brackets around app names | "Private app [[name]] doesn't exist" | Use plain strings in list |

## Modifying Rules

### Adding a New Rule

1. Add the rule resource to the appropriate file
2. Set `rule_order` to position it correctly
3. Update `depends_on` for rules that should come after it
4. Run `terraform plan` to verify ordering

### Disabling a Rule

Set `enabled = "0"` instead of deleting:

```hcl
resource "netskope_npa_rules" "temporary_access" {
  enabled = "0"  # Disabled but preserved
  # ...
}
```

## Example terraform.tfvars

```hcl
environment = "production"

# Map these to your actual IdP groups
admin_groups = [
  "IT-Administrators",
  "SRE-Team"
]

developer_groups = [
  "Engineering",
  "Developers"
]

dba_groups = [
  "Database-Admins"
]

blocked_groups = [
  "Terminated-Users",
  "Security-Quarantine"
]

# Tags used in your private app definitions
web_app_tags = ["web-tier"]
database_app_tags = ["database-tier"]
infrastructure_app_tags = ["infrastructure", "ssh"]
```

## Cleanup

```bash
terraform destroy
```

**Warning**: Destroying rules may disrupt user access. Consider disabling rules first.

## Related Examples

- [private-app-inventory](../private-app-inventory/) - Create tagged applications
- [browser-app](../browser-app/) - Simple browser-accessible app