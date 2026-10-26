# Policy as Code with NPA Rules

Manage Netskope NPA access policies using Terraform. This example shows how to create policy groups, define access rules, manage rule ordering, and implement role-based access patterns.

**Difficulty:** Intermediate

**Provider requirement: >= 0.4.13** (block-rule updates, rule ordering on update, and template handling were all fixed in that release — see [guides/upgrading-to-0.4.13.md](../../../guides/upgrading-to-0.4.13.md)).

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
1. Deny blocked users          <- Broad deny (terminated/quarantined)
2. Admin SSH access            <- Privileged access (specific users + apps)
3. Admin database access
4. Require endpoint protection <- Posture-gated access
5. DBA database access         <- Team-based access
6. Developer web access
7. General browser access      <- Broad access
8. Deny all other              <- Catch-all deny (optional, commented out)
```

This order is applied by `netskope_npa_rules_order` in `rules-order.tf`. NPA evaluates by most-specific-match, so the list order is for readability and auditing.

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

> **`group_order` is create-time only.** Changing `group_order` on an existing policy group currently fails with a backend error (`A value is required for bind parameter 'new_order'`, provider issue [#110](https://github.com/netskopeoss/terraform-provider-netskope/issues/110)). Set it when you create the group and leave it alone afterwards; to move a group, recreate it.

## Prerequisites

- Private applications already created with appropriate tags (see [private-app-inventory](../private-app-inventory/))
- User groups configured in your IdP
- IdP groups synced to Netskope
- Terraform 1.0+ installed

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration |
| `variables.tf` | User groups, app tags, and block template name |
| `data.tf` | Discover existing apps and policy groups |
| `rules-deny.tf` | Block rules for terminated/quarantined users |
| `rules-admin.tf` | Admin/privileged access rules |
| `rules-teams.tf` | Team-based access rules |
| `rules-device-posture.tf` | Device posture rules (v0.4.2+) |
| `rules-general.tf` | General access and optional catch-all deny |
| `rules-order.tf` | `netskope_npa_rules_order` — the list position of every rule |
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

### Rule Ordering

Every rule sets `rule_order = { order = "bottom" }` with `lifecycle { ignore_changes = [rule_order] }`, and one `netskope_npa_rules_order` resource (`rules-order.tf`) lists all rule IDs in the desired order:

```hcl
# In each rule
rule_order = { order = "bottom" }      # create-time placement only
lifecycle { ignore_changes = [rule_order] }

# Once, in rules-order.tf
resource "netskope_npa_rules_order" "main" {
  rule_ids = local.ordered_rule_ids    # deny first, allow rules below
}
```

Why this shape:

- `rule_order` is only honoured when a rule is **created**. Since provider v0.4.13 it is never sent on update, so editing a rule leaves it where it is. (Before 0.4.13 the provider re-sent the create-time value on every update, which silently moved edited rules to the bottom of the policy — [#129](https://github.com/netskopeoss/terraform-provider-netskope/issues/129).)
- `"bottom"` puts a brand-new rule at the end of the list, away from live traffic, until the order resource positions it.
- `ignore_changes` stops a later edit of the `rule_order` block from showing a plan diff that would apply without effect.
- `depends_on` chains between rules are not needed for ordering and have been removed.

For `for_each`-driven rule sets, the same pattern scales: `rule_ids = [for p in local.policies : netskope_npa_rules.bulk[p.name].id]`. Adding a rule adds one line; removing one removes one line; reordering changes only the order resource. The order resource reads the live order first and moves only rules that are out of place ([#125](https://github.com/netskopeoss/terraform-provider-netskope/issues/125)).

## Block Rules

The `rules-deny.tf` file creates a block rule for terminated or quarantined users. Block rules require a template — the block page shown to the user.

**Critical:** use the template **display name**, not the file name:

```hcl
match_criteria_action = {
  action_name = "block"
  emit_alert  = true
  template    = "Generic Block"  # display name — NOT "block_page.html"
}
```

Find template display names in the Netskope UI: **Settings > Security Cloud Platform > NPA > Block Templates**. Set `block_template` in `terraform.tfvars` to a name that exists on your tenant.

The API accepts the display name on write but returns the internal file name on read. **Expect one diff per block rule on the first plan after create or import** — `template = "block_page.html" -> "Generic Block"` — apply it, and every later plan is empty. The provider stores the display name in Terraform private state, so this works the same on Terraform Cloud as on a laptop. Sending the file name yourself returns `"Undefined template: block_page.html"`. See the provider README, [Template Name Resolution](https://github.com/netskopeoss/terraform-provider-netskope#template-name-resolution), and [`examples/npa/block-rules-and-ordering`](../block-rules-and-ordering/) for the full lifecycle including in-place updates.

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| `enabled = true` | Type error | Use string: `enabled = "1"` |
| `enabled = 1` | Type error | Use string: `enabled = "1"` |
| Brackets around app names | "Private app [[name]] doesn't exist" | Use plain strings in list |
| `template = "block_page.html"` in block rule | "Undefined template: block_page.html" | Use display name: `"Generic Block"` |
| Treating the first `"block_page.html" -> "Generic Block"` diff as a bug | One in-place update after create/import | Apply it once; later plans are empty |
| Editing `rule_order` to move an existing rule | Plan diff applies with no effect | Change its position in `rules-order.tf` |
| Changing `group_order` on an existing policy group | Backend error (#110) | Set on create only |

## Modifying Rules

### Adding a New Rule

1. Add the rule resource to the appropriate file with `rule_order = { order = "bottom" }` and `ignore_changes = [rule_order]`
2. Insert its ID at the desired position in `local.ordered_rule_ids` (`rules-order.tf`)
3. Run `terraform plan` — the new rule is created and only the rules that must shift are moved

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