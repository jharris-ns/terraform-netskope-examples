# Block Rules and Rule Ordering

Demonstrates the full lifecycle of NPA block rules and large-scale rule ordering. Exercises every code path that was broken or unclear in [#74](https://github.com/netskopeoss/terraform-provider-netskope/issues/74), [#79](https://github.com/netskopeoss/terraform-provider-netskope/issues/79), [#106](https://github.com/netskopeoss/terraform-provider-netskope/issues/106), [#124](https://github.com/netskopeoss/terraform-provider-netskope/issues/124), and [#125](https://github.com/netskopeoss/terraform-provider-netskope/issues/125).

**Provider requirement: >= 0.4.12**

| Fix | Version |
|---|---|
| Block rule in-place update fails with "template field is required" (#124) | 0.4.12 |
| `npa_rules_order` re-PATCHes every rule on any `rule_ids` change (#125) | 0.4.12 |
| `device_classification_id` rejects `"managed"` / `"unmanaged"` strings (#74) | 0.4.9 |
| Read crashes on rules with `classification` set (#106) | 0.4.9 |
| Block template drifts from display name to `.html` filename (#79) | 0.4.4 |

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
# Edit terraform.tfvars with your policy_group_id and block_template
terraform init
terraform plan
terraform apply
```

## Block rule template field

Block rules (and periodic re-authentication rules) require a `template` in `match_criteria_action`. Always use the **display name** shown in the Netskope UI:

> Settings > Security Cloud Platform > NPA > Block Templates

```hcl
match_criteria_action = {
  action_name = "block"
  emit_alert  = true
  template    = "Generic Block"     # display name — NOT "5.html"
}
```

### How the provider translates names

The provider calls `GET /api/v2/templates/usernotifications` once per session to build a bidirectional cache of display names ↔ `.html` filenames. When this succeeds:

- **On create/update**: the display name from config is sent to the API — no transformation needed for block rules (the API translates it server-side).
- **On read (GET)**: the API returns `"5.html"`; the provider translates it back to `"Generic Block"` before storing in state. State always holds the display name. Plans are clean.

### When the templates API returns 403

If `GET /api/v2/templates/usernotifications` is not accessible with your API token, the provider degrades gracefully:

1. On the **first `terraform plan`** after a fresh `terraform init` (or after any operation that stores `"5.html"` in state), you will see:
   ```
   ~ template = "5.html" -> "Generic Block"
   ```
2. **Apply it** — the update sends `"Generic Block"`, which the API accepts. State is corrected.
3. **Subsequent plans in the same session** are clean (`"Generic Block"` == `"Generic Block"`).

This is a known limitation when the templates API is unavailable. Supply the display name in config (not the filename) — the provider handles the rest.

> **Verify access:** ensure your API token can call `GET /api/v2/templates/usernotifications`. If it returns 403, contact your Netskope administrator to grant access.

## Device classification

`device_classification_id` accepts both string and numeric values:

| Value | Meaning |
|---|---|
| `"managed"` | Built-in: device enrolled in corporate MDM |
| `"unmanaged"` | Built-in: device not enrolled in corporate MDM |
| `"16715"` | Numeric ID of a custom classification tag |

```hcl
# Built-in string values (supported since v0.4.9)
device_classification_id = ["managed"]
device_classification_id = ["unmanaged"]

# Mixed: managed plus a custom tag
device_classification_id = ["managed", "16715"]
```

Find custom tag IDs with:
```hcl
data "netskope_device_classification_options_list" "all" {}
output "options" { value = data.netskope_device_classification_options_list.all.options }
```

## Importing existing UI-created block rules

To bring a block rule created in the Netskope UI under Terraform management:

**1. Find the rule ID** — from the Netskope UI URL or via the API:
```hcl
data "netskope_npa_rules_list" "all" {}
output "rules" { value = data.netskope_npa_rules_list.all.data }
```

**2. Add the resource block** in `rules-block.tf` with the correct display name in `template`.

**3. Import:**
```bash
terraform import netskope_npa_rules.block_users <rule_id>
```

**4. Plan** — you should see exactly one diff:
```
~ template = "5.html" -> "Generic Block"
```
This is expected. The import stored the raw API filename in state; the plan corrects it to your config display name.

**5. Apply** — the rule is now fully managed. Subsequent plans are clean.

## Rule ordering

`netskope_npa_rules_order` manages the list position of all rules. NPA evaluates rules by **most-specific-match**, not top-to-bottom, so list position is for operational visibility only.

### The recommended pattern

Every rule resource:
```hcl
rule_order = { order = "bottom" }   # lands at the bottom on create

lifecycle {
  ignore_changes = [rule_order]     # prevents re-sending rule_order on update
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

### Removing a rule (v0.4.12 behaviour)

In v0.4.11, removing one ID from `rule_ids` caused the provider to PATCH every remaining rule to `top` — O(n) API calls, 4+ minutes for 200 rules, with the live list visibly scrambled mid-apply.

In v0.4.12, the provider reads the live order first and only moves rules that are out of place. Removing a rule that was already in relative order sends **zero PATCHes** to the API.

Steps:
1. Remove the rule resource from `rules-block.tf` or `rules-allow.tf`.
2. Remove its ID reference from `local.ordered_rule_ids` in `rules-order.tf`.
3. `terraform apply` — the rule is destroyed; no other rules are moved.

### Adding a rule

1. Add the rule resource with `rule_order = { order = "bottom" }`.
2. Insert its ID at the desired position in `local.ordered_rule_ids`.
3. `terraform apply` — the rule is created, then only the rules that need to shift to make room are PATCHed.

## Testing the fix for issue #124

To verify that block rule updates work correctly on your tenant:

1. Apply this example (creates all rules).
2. Change `emit_alert` on one of the block rules:
   ```hcl
   match_criteria_action = {
     action_name = "block"
     emit_alert  = true      # was false
     template    = var.block_template
   }
   ```
3. `terraform plan` — should show a clean in-place update with no template drift.
4. `terraform apply` — should succeed with no "template field is required" error.
5. `terraform plan` again — should show no changes.
