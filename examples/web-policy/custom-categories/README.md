# Custom Categories

Combine URL lists and destination profiles into named policy objects that can be referenced in Real-time Protection rules.

**Difficulty:** Simple
**Provider version:** >= 0.4.8

## Overview

A URL list on its own has no effect in policy — it must first be attached to a **custom category**, which is the object that Real-time Protection policies actually reference. Without Terraform support for custom categories, teams managing URL lists as code still had to log into the UI to wire them into policy.

This example shows the complete chain:

```
URL List (block)  ─┐
                    ├──> Custom Category ──> Real-time Protection Policy
URL List (allow)  ─┘  (exception)
```

## Quick Start

```bash
cd examples/web-policy/custom-categories

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform plan
```

## What This Creates

- **`social-media-sites`** URL list — Facebook, Instagram, TikTok, Twitter, X
- **`marketing-social-media-allowed`** URL list — LinkedIn, YouTube (exceptions)
- **`internal-domains-bypass`** URL list — `*.corp.example.com` wildcard bypass list
- **`Social Media - Employee Blocked`** custom category — includes the block list, excludes the marketing exceptions
- **`Social Media - Marketing Allowed`** custom category — includes only the marketing-allowed list
- **`Internal Domains - Bypass`** custom category — for steering bypass policies

## Key Patterns

### Attach a URL List to a Custom Category

```hcl
resource "netskope_urllist" "blocked" {
  name = "blocked-sites"
  data = { urls = ["example.com"], type = "exact" }
}

resource "netskope_custom_category" "blocked" {
  name               = "Blocked Sites"
  description        = "Sites blocked by corporate policy."
  included_url_lists = [tostring(netskope_urllist.blocked.id)]
}
```

> **Note:** `included_url_lists` expects numeric string IDs. Use `tostring()` when referencing the integer `id` attribute of a `netskope_urllist` resource.

### Include a Predefined Netskope Category

```hcl
resource "netskope_custom_category" "social" {
  name                          = "All Social Media"
  included_predefined_categories = ["500"]  # Netskope built-in Social Media category
  included_url_lists            = [tostring(netskope_urllist.extra.id)]
}
```

Find predefined category IDs in the Netskope UI under **Policies > Web > Categories**.

### Exclude URLs from a Category

```hcl
resource "netskope_custom_category" "social_except_linkedin" {
  name               = "Social Media (LinkedIn excluded)"
  included_url_lists = [tostring(netskope_urllist.all_social.id)]
  excluded_url_lists = [tostring(netskope_urllist.linkedin_only.id)]
}
```

## Common Mistakes

| Mistake | What Happens | Fix |
|---------|--------------|-----|
| Referencing `url_list.id` directly (integer) | Type error in plan | Wrap with `tostring()` |
| Duplicate category name | API returns 400 | Category names must be unique per tenant |
| Name longer than 100 characters | API rejects | Keep names concise |
| Missing API group permission | 403 error | Token needs `objects_custom_category` with `rwa` |

## Cleanup

```bash
terraform destroy
```

Custom categories must not be actively referenced in a Real-time Protection policy before they can be deleted. Remove the policy reference first.

## Related Examples

- [service-objects/](../service-objects/) — Port/protocol profiles for firewall rules
- [npa/rbac-roles/](../../npa/rbac-roles/) — Admin role definitions
