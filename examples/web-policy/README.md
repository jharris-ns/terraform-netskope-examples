# Web Policy Examples

Terraform examples for managing Netskope Real-time Protection policy objects — the building blocks that determine how web traffic is categorized, filtered, and controlled.

## Prerequisites

- Netskope tenant with **Next Gen SWG** or **CASB** licensed
- REST API v2 access enabled
- Terraform >= 1.0
- API token with the appropriate RBAC permissions (`objects_custom_category`, `objects_service` with `rwa` for deploy)

## Examples

| Example | Difficulty | Description |
|---------|------------|-------------|
| [custom-categories/](./custom-categories/) | Simple | Combine URL lists and destination profiles into a single policy object |
| [service-objects/](./service-objects/) | Simple | Define named port/protocol profiles for firewall policy rules |

## How These Objects Fit Together

```
URL Lists  ──┐
             ├──> Custom Category ──> Real-time Protection Policy
Dest. Profiles ─┘

Service Objects ──────────────> Firewall Policy Rule
```

Custom categories and service objects are referenced by name in Real-time Protection policies. Managing them in Terraform closes the IaC gap — previously, Terraform-managed URL lists still required manual UI work to become effective in policy.
