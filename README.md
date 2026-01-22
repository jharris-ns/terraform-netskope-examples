# Netskope Terraform Examples

Learn how to use the [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest) through hands-on tutorials and working examples.

**Why manage NPA with Terraform?**
- Version control your private app and policy configurations
- Automate publisher deployments across cloud environments
- Reduce manual configuration and human error

## Examples

All examples are in the [`code/`](./code/) directory with deployment instructions.

### Application Management

| Example | Description |
|---------|-------------|
| [browser-app](./code/browser-app/) | Browser-accessible private application |
| [client-app](./code/client-app/) | SSH, RDP, and database access via NPA client |
| [private-app-inventory](./code/private-app-inventory/) | Manage multiple apps at scale with variables |

### Publisher Deployment

| Example | Description |
|---------|-------------|
| [publisher-management](./code/publisher-management/) | Publisher lifecycle and upgrades |
| [publisher-aws](./code/publisher-aws/) | Deploy NPA publisher in AWS with VPC and NAT |

### Policy & Access Control

| Example | Description |
|---------|-------------|
| [policy-as-code](./code/policy-as-code/) | Access policies with deny rules and ordering |

### Complete Solutions

| Example | Description |
|---------|-------------|
| [full-deployment](./code/full-deployment/) | End-to-end NPA setup: publishers, apps, and policies |

## Where to Start

| Goal | Guide |
|------|-------|
| New to Terraform | [Terraform Basics](./getting-started/terraform-basics.md) |
| Deploy your first private app | [Quick Start](./getting-started/quick-start.md) |
| Project structure and naming | [Best Practices](./guides/best-practices.md) |

## Quick Start

```bash
git clone https://github.com/netskopeoss/terraform-netskope-examples.git
cd terraform-netskope-examples/code/browser-app

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform apply
```

For detailed setup instructions, see the [Quick Start guide](./getting-started/quick-start.md).

## Prerequisites

- Netskope tenant with REST API v2 access ([setup guide](./getting-started/quick-start.md#step-1-create-an-api-key))
- Terraform >= 1.0
- For AWS examples: AWS CLI configured with appropriate permissions

## Resources

- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest) - Terraform Registry
- [Provider Documentation](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs) - Resources and data sources
- [Netskope Documentation](https://docs.netskope.com) - Product documentation

---

[Contributing](./CONTRIBUTING.md) | [License](./LICENSE) (Apache 2.0)