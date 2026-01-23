# Netskope Terraform Examples

Learn how to use the [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest) through working examples.

**Why manage NPA with Terraform?**
- Version control your private app and policy configurations
- Automate publisher deployments across cloud environments
- Reduce manual configuration and human error

## Examples

All examples are in the [`examples/`](./examples/) directory with deployment instructions.

Users with limited Terraform experience should first review [Patterns Used in Our Examples](./getting-started/terraform-basics.md#patterns-used-in-our-examples) for explanations of the patterns used throughout these examples.

### Simple

| Example | Description |
|---------|-------------|
| [browser-app](./examples/browser-app/) | Browser-accessible private application |
| [client-app](./examples/client-app/) | SSH, RDP, and database access via NPA client |
| [publisher-management](./examples/publisher-management/) | Publisher lifecycle and upgrades |

### Intermediate

| Example | Description |
|---------|-------------|
| [private-app-inventory](./examples/private-app-inventory/) | Manage multiple apps at scale with variables |
| [publisher-aws](./examples/publisher-aws/) | Deploy NPA publisher in AWS with VPC and NAT |
| [policy-as-code](./examples/policy-as-code/) | Access policies with deny rules and ordering |

### Advanced

| Example | Description |
|---------|-------------|
| [full-deployment](./examples/full-deployment/) | End-to-end NPA setup: publishers, apps, and policies |

## Where to Start

| Goal | Guide |
|------|-------|
| New to Terraform | [Terraform Basics](./getting-started/terraform-basics.md) |
| Deploy your first private app | [Quick Start](./getting-started/quick-start.md) |
| Project structure and naming | [Best Practices](./guides/best-practices.md) |

## Quick Start

```bash
git clone https://github.com/netskopeoss/terraform-netskope-examples.git
cd terraform-netskope-examples/examples/browser-app

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