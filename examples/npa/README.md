# Netskope Private Access (NPA) Examples

Terraform examples for managing [Netskope Private Access](https://docs.netskope.com/en/netskope-private-access/) — private applications, publishers, and access policies.

## Prerequisites

- Netskope tenant with **NPA** licensed
- REST API v2 access enabled
- Terraform >= 1.0
- At least one publisher registered (for app examples)
- For AWS examples: AWS CLI configured with appropriate permissions

## Examples

### Getting Started
Start here if you're new to Netskope Terraform:

| Example | Difficulty | Description |
|---------|------------|-------------|
| [browser-app/](./browser-app/) | Simple | Browser-accessible private application |
| [client-app/](./client-app/) | Simple | SSH, RDP, and database access via NPA client |

### Publisher & Local Broker Deployment

| Example | Difficulty | Description |
|---------|------------|-------------|
| [publisher-management/](./publisher-management/) | Simple | Publisher lifecycle, upgrades, and alerts |
| [local-broker-management/](./local-broker-management/) | Simple | Local broker configuration and tokens |
| [publisher-aws/](./publisher-aws/) | Intermediate | Deploy NPA publisher in AWS with VPC |

### Application Management

| Example | Difficulty | Description |
|---------|------------|-------------|
| [private-app-inventory/](./private-app-inventory/) | Intermediate | Manage multiple apps at scale with variables |
| [full-deployment/](./full-deployment/) | Advanced | Complete NPA setup with publishers, apps, and policies |

### Access Control

| Example | Difficulty | Description |
|---------|------------|-------------|
| [policy-as-code/](./policy-as-code/) | Intermediate | NPA access policies with deny rules and team-based access |
| [device-classification/](./device-classification/) | Simple | Device posture enforcement via classification tags (v0.4.2+) |
| [rbac-labels/](./rbac-labels/) | Simple | Label-based access control for resource management (v0.4.0+) |

## Key Patterns

### Publisher Lookup
Most NPA examples use this pattern to find an existing publisher:

```hcl
data "netskope_npa_publishers_list" "all" {}
locals {
  publisher = var.publisher_name != null ? (
    [for p in data.netskope_npa_publishers_list.all.data.publishers : p if p.publisher_name == var.publisher_name][0]
  ) : data.netskope_npa_publishers_list.all.data.publishers[0]
}
```

### Browser vs Client Apps
- **Browser-based**: `real_host` + `private_app_protocol` + `clientless_access = true`
- **Client-based**: `private_app_hostname` + `protocols` array + `clientless_access = false`

See [browser-app/](./browser-app/) and [client-app/](./client-app/) for details.
