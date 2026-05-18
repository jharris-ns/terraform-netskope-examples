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

NPA rules use **most-specific-match** evaluation — the rule whose criteria most precisely match the request is applied, regardless of list position. The `rule_order` attribute controls list placement for organizational purposes only.

## Rule List Organization

```
1. Deny blocked users     <- Broad deny (terminated/quarantined)
2. Admin SSH access       <- Privileged access (specific users + apps)
3. Admin database access
4. Developer web access   <- Team-based access
5. DBA database access
6. General browser access <- Broad access
7. Deny all other         <- Catch-all deny
```

## Best Practice: Use a Dedicated Policy Group

NPA rules should be organized within their own policy group rather than placed in the Default group. This keeps Terraform-managed rules isolated from manually-created rules and makes it easier to manage rule lifecycle.

```hcl
resource "netskope_npa_policy_groups" "terraform" {
  group_name = "Terraform-Managed"

  group_order = {
    group_id = "2"
    order    = "after"
  }
}
```

Then reference `netskope_npa_policy_groups.terraform.id` as the `group_id` for all rules in this group.

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
| `rules-device-posture.tf` | Device posture rules (v0.4.2+) |
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

### Bulk Ordering with netskope_npa_rules_order

For larger deployments where you manage many rules with `for_each`, the `netskope_npa_rules_order` resource lets you control the list position of all rules in a single place:

```hcl
locals {
  policies = yamldecode(file("policies.yaml"))
  policy_map = { for p in local.policies : p.name => p }
}

# Step 1: Create all rules at bottom (parallel, fast)
resource "netskope_npa_rules" "bulk" {
  for_each = local.policy_map

  rule_name = each.value.name
  enabled   = "1"
  group_id  = netskope_npa_policy_groups.terraform.id

  rule_data = {
    policy_type           = "private-app"
    match_criteria_action = { action_name = each.value.action }
    private_apps          = each.value.apps
    user_groups           = each.value.groups
    access_method         = ["Client"]
  }

  rule_order = { order = "bottom" }

  lifecycle {
    ignore_changes = [rule_order]
  }
}

# Step 2: Set list positions (list order = display order in UI)
resource "netskope_npa_rules_order" "main" {
  rule_ids = [for p in local.policies : netskope_npa_rules.bulk[p.name].id]
}
```

With this pattern:

- **Adding a rule**: add a line to the YAML at the desired position. Only the new rule is created; existing rules are untouched.
- **Removing a rule**: remove the line. The rule is destroyed and the order resource updates.
- **Reordering**: move lines in the YAML. Only the order resource updates — no rules are re-created.

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| `enabled = true` | Type error | Use string: `enabled = "1"` |
| `enabled = 1` | Type error | Use string: `enabled = "1"` |
| Missing `depends_on` | Rules created in unpredictable order | Add `depends_on` chain |
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

## Device Posture Rules (v0.4.2+)

The `rules-device-posture.tf` file adds rules that restrict access based on device classification tags. To use:

1. Create device classification tags in Settings > Device Classification
2. Add tag names to `terraform.tfvars`:
   ```hcl
   required_device_tags = ["CrowdStrike Installed"]
   ```
3. The rule is only created if both matching apps and tags exist

See [device-classification](../device-classification/) for a standalone example.

## Related Examples

- [private-app-inventory](../private-app-inventory/) - Create tagged applications
- [browser-app](../browser-app/) - Simple browser-accessible app
- [device-classification](../device-classification/) - Device posture enforcement
- [rbac-labels](../rbac-labels/) - Label-based access control