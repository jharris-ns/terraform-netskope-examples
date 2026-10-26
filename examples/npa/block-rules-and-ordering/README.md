# Block Rules and Rule Ordering

Demonstrates the full lifecycle of NPA block rules and rule ordering at scale: creating block rules with a template, updating them in place, importing UI-created rules, and letting one `netskope_npa_rules_order` resource own the list position of every rule.

**Provider requirement: >= 0.4.13.** Earlier releases had bugs in exactly the paths this example exercises — block-rule updates failed ([#124](https://github.com/netskopeoss/terraform-provider-netskope/issues/124)), every update silently moved the rule to the bottom of the policy ([#129](https://github.com/netskopeoss/terraform-provider-netskope/issues/129)), and the template field showed a diff on every Terraform Cloud run ([#79](https://github.com/netskopeoss/terraform-provider-netskope/issues/79), [#105](https://github.com/netskopeoss/terraform-provider-netskope/issues/105), [#129](https://github.com/netskopeoss/terraform-provider-netskope/issues/129)). If you are upgrading, read [guides/upgrading-to-0.4.13.md](../../../guides/upgrading-to-0.4.13.md) first.

## What this example creates

| Resource | Description |
|---|---|
| `netskope_npa_publisher.main` | One publisher |
| `netskope_npa_private_app.internal_api` | Client-access app |
| `netskope_npa_private_app.internal_portal` | Clientless portal app |
| `netskope_npa_rules.block_users` | Block by user group (optional) |
| `netskope_npa_rules.block_unmanaged_devices` | Block unmanaged devices |
| `netskope_npa_rules.allow_admins` | Allow by user group (optional) |
| `netskope_npa_rules.allow_managed_devices` | Allow managed devices only |
| `netskope_npa_rules.allow_all_clientless` | Allow all clientless portal access |
| `netskope_npa_rules_order.main` | Manages list position of all rules |

## Quick start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set block_template to a template display name that exists on your tenant
terraform init
terraform apply          # creates everything
terraform apply          # second apply: converges the template field (see below) — expected
terraform plan           # empty
```

## Block rule template field

Block rules require a `template` in `match_criteria_action`. Use the **display name** shown in the Netskope UI under *Settings > Security Cloud Platform > NPA > Block Templates*:

```hcl
match_criteria_action = {
  action_name = "block"
  emit_alert  = true
  template    = "Generic Block"     # display name — NOT "block_page.html"
}
```

The API accepts the display name on write but returns an internal filename (for example `block_page.html`) on read. The provider reconciles the two using Terraform resource private state, which is stored in your state file, so the behaviour is the same on a laptop, in CI and on Terraform Cloud, and it does **not** depend on any extra API endpoint for block rules.

### What to expect in `terraform plan`

**First plan after creating or importing a block rule** — one diff per block rule:

```
~ rule_data = {
    ~ match_criteria_action = {
        ~ template = "block_page.html" -> "Generic Block"
      }
  }
```

Apply it. This is the provider recording the display name; nothing changes in the tenant. **Every plan after that is empty**, in every process.

**Updating a block rule** — change `emit_alert`, `user_groups`, `private_apps`, or anything else, and the plan shows only that change. The apply succeeds and the rule keeps its position in the policy list.

**Changing the template** — change `block_template` to another display name and the plan shows the change; apply it and the new template is in effect.

### Known limitation

If someone changes a block rule's template in the Netskope UI to a *different* template while your configuration still names the original, Terraform does not detect it. Changing the display name in configuration is always detected.

## Device classification

Two separate fields control device classification:

| Field | Accepts | Example |
|---|---|---|
| `classification` | Built-in string values: `"managed"` or `"unmanaged"` | `classification = ["managed"]` |
| `device_classification_id` | Numeric custom tag IDs only | `device_classification_id = ["16715"]` |

**Do NOT put `"managed"` or `"unmanaged"` in `device_classification_id`** — the API rejects string values there with `"device_classification_id should be integer"`.

```hcl
# Built-in: block devices not enrolled in corporate MDM
classification = ["unmanaged"]

# Built-in: allow only enrolled (managed) devices
classification = ["managed"]

# Custom tag ID (numeric, from Settings > Device Classification)
device_classification_id = ["16715"]

# Combined: built-in managed + a custom tag
classification            = ["managed"]
device_classification_id  = ["16715"]
```

Find custom tag IDs with:
```hcl
data "netskope_device_classification_options_list" "all" {}
output "options" { value = data.netskope_device_classification_options_list.all.options }
```

## Importing existing UI-created block rules

**1. Find the rule ID** — from the Netskope UI URL or via the API:
```hcl
data "netskope_npa_rules_list" "all" {}
output "rules" { value = data.netskope_npa_rules_list.all.data }
```

**2. Add the resource block** in `rules-block.tf` with the template **display name**.

**3. Import:**
```bash
terraform import netskope_npa_rules.block_users <rule_id>
```

**4. Plan** — exactly one diff, `template = "block_page.html" -> "Generic Block"`. Apply it.

**5. Plan again** — empty. The rule is fully managed.

## Rule ordering

`netskope_npa_rules_order` manages the list position of all rules. NPA evaluates rules by **most-specific-match**, not top-to-bottom, so list position is for operational visibility and auditing.

### The pattern

Every rule resource:
```hcl
# rule_order sets the position on CREATE only. The provider does not send it on
# update (since v0.4.13), so changing it here later has no effect on the live
# list; use netskope_npa_rules_order for that. ignore_changes keeps a later
# edit of this block from producing a no-op plan diff.
rule_order = { order = "bottom" }

lifecycle {
  ignore_changes = [rule_order]
}
```

`netskope_npa_rules_order` then owns all final positions:
```hcl
resource "netskope_npa_rules_order" "main" {
  rule_ids = [
    netskope_npa_rules.block_users[0].id,
    netskope_npa_rules.block_unmanaged_devices.id,
    netskope_npa_rules.allow_admins[0].id,
    # ...
  ]
}
```

Why `"bottom"` on create: a new rule lands at the end of the list, away from live traffic, until `netskope_npa_rules_order` places it. Why `ignore_changes`: `rule_order` is not returned by the API and is only used on create; without `ignore_changes`, editing the block later would show a diff that applies without effect.

### Removing a rule

1. Remove the rule resource from `rules-block.tf` or `rules-allow.tf`.
2. Remove its ID reference from `local.ordered_rule_ids` in `rules-order.tf`.
3. `terraform apply` — the rule is destroyed. `netskope_npa_rules_order` reads the live order first and moves nothing if the remaining rules are already in the right relative order ([#125](https://github.com/netskopeoss/terraform-provider-netskope/issues/125), fixed in 0.4.12).

### Adding a rule

1. Add the rule resource with `rule_order = { order = "bottom" }` and `ignore_changes = [rule_order]`.
2. Insert its ID at the desired position in `local.ordered_rule_ids`.
3. `terraform apply` — the rule is created at the bottom, then only the rules that need to shift are moved.

## Verifying the update path on your tenant

1. Apply this example twice (the second apply converges the template field).
2. Change `emit_alert` on `block_unmanaged_devices` from `false` to `true`.
3. `terraform plan` — exactly one attribute changes; no template diff.
4. `terraform apply` — succeeds.
5. In the Netskope UI, confirm the block rules are still above the allow rules.
6. `terraform plan` — empty.
