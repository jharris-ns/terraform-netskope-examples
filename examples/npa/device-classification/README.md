# Device Classification in NPA Rules

Enforce device posture requirements on private application access using device classification tags.

**Difficulty:** Simple
**Provider version:** >= 0.4.2

## Overview

Device classification tags are labels created in the Netskope UI (Settings > Device Classification) that identify device posture states like "CrowdStrike Installed", "Managed", or "SentinelOne Active". Each tag has a numeric ID that can be referenced in NPA policy rules via the `device_classification_id` field.

This example uses the `netskope_device_classification_tag_list` data source to look up tag IDs dynamically, so you don't need to hardcode them.

## Quick Start

```bash
cd examples/npa/device-classification

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan
```

## Prerequisites

- At least one device classification tag created in **Settings > Device Classification**
- At least one NPA publisher registered
- Provider version >= 0.4.2

## What This Creates

- A private application definition
- An NPA rule that only allows access from devices matching a specific classification tag
- Uses `precondition` to fail early if the required tag doesn't exist

## Key Patterns

### Look Up All Tags

```hcl
data "netskope_device_classification_tag_list" "all" {}
```

### Build a Name-to-ID Map

```hcl
locals {
  tag_ids_by_name = {
    for t in data.netskope_device_classification_tag_list.all.tags :
    t.name => t.tag_id
  }
}
```

### Use in a Rule

```hcl
device_classification_id = [tostring(local.tag_ids_by_name["CrowdStrike Installed"])]
```

### Multiple Classifications (OR logic)

```hcl
device_classification_id = [
  tostring(local.tag_ids_by_name["CrowdStrike Installed"]),
  tostring(local.tag_ids_by_name["SentinelOne Installed"]),
]
```

### All Classifications ("Managed" Equivalent)

The Netskope UI shows "Managed" and "Unmanaged" as device categories, but these are convenience groupings — not distinct API entities. To replicate "Managed" in Terraform, include all device classification tag IDs:

```hcl
device_classification_id = [
  for t in data.netskope_device_classification_tag_list.all.tags :
  tostring(t.tag_id)
]
```

A device matching ANY tag is considered "managed".

### Validate Tag Exists

```hcl
lifecycle {
  precondition {
    condition     = contains(keys(local.tag_ids_by_name), "CrowdStrike Installed")
    error_message = "Required device classification tag not found."
  }
}
```

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| Tag ID without `tostring()` | Type error | Wrap: `tostring(tag.tag_id)` |
| Tag name typo | Empty list, index error | Use `precondition` to validate |
| Using string IDs like `"managed"` | API rejects: "should be integer" | Use numeric IDs from data source |

## Customization

Edit `var.required_tag_name` to match a tag on your tenant:

```bash
terraform apply -var='required_tag_name=SentinelOne Installed'
```

Or create a `terraform.tfvars`:

```hcl
required_tag_name = "Managed Devices"
publisher_name    = "dc-west-publisher-01"
```

## Related Examples

- [policy-as-code](../policy-as-code/) - Combine device classification with team-based access rules
- [client-app](../client-app/) - Basic client-based application setup
