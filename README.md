# Netskope Terraform Examples

Learn how to use the [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest) through working examples.

**Why manage Netskope with Terraform?**
- Version control your security configurations
- Automate deployments across cloud environments
- Reduce manual configuration and human error

## Examples

All examples are in the [`examples/`](./examples/) directory, organized by product area.

Users with limited Terraform experience should first review [Patterns Used in Our Examples](./getting-started/terraform-basics.md#patterns-used-in-our-examples) for explanations of the patterns used throughout these examples.

### NPA (Netskope Private Access)

| Example | Difficulty | Description |
|---------|------------|-------------|
| [browser-app](./examples/npa/browser-app/) | Simple | Browser-accessible private application |
| [client-app](./examples/npa/client-app/) | Simple | SSH, RDP, and database access via NPA client |
| [publisher-management](./examples/npa/publisher-management/) | Simple | Publisher lifecycle and upgrades |
| [local-broker-management](./examples/npa/local-broker-management/) | Simple | Local broker configuration and tokens |
| [private-app-inventory](./examples/npa/private-app-inventory/) | Intermediate | Manage multiple apps at scale with variables |
| [publisher-aws](./examples/npa/publisher-aws/) | Intermediate | Deploy NPA publisher in AWS with VPC and NAT |
| [policy-as-code](./examples/npa/policy-as-code/) | Intermediate | Access policies with deny rules and ordering |
| [full-deployment](./examples/npa/full-deployment/) | Advanced | End-to-end NPA setup: publishers, apps, and policies |

### DNS Security

| Example | Difficulty | Description |
|---------|------------|-------------|
| [basic-profile](./examples/dnsprofiles/basic-profile/) | Simple | DNS profile with domain allow and block lists |
| [security-categories](./examples/dnsprofiles/security-categories/) | Intermediate | Category-based blocking and sinkholing |
| [full-deployment](./examples/dnsprofiles/full-deployment/) | Advanced | Complete DNS setup with tunneling, custom DNS, inheritance |

### IPSec

| Example | Difficulty | Description |
|---------|------------|-------------|
| [vpn](./examples/ipsec/vpn/) | Intermediate | IPSec tunnel steering configuration |
| [aws-transitgateway-vpn](./examples/ipsec/aws-transitgateway-vpn/) | Advanced | AWS Transit Gateway + Netskope IPSec integration |

## Where to Start

| Goal | Guide |
|------|-------|
| New to Terraform | [Terraform Basics](./getting-started/terraform-basics.md) |
| Deploy your first private app | [Quick Start](./getting-started/quick-start.md) |
| Project structure and naming | [Best Practices](./guides/best-practices.md) |
| Upgrading from 0.3.2 | [Upgrade Guide](./guides/upgrading-to-0.3.4.md) |

## Quick Start

```bash
git clone https://github.com/netskopeoss/terraform-netskope-examples.git
cd terraform-netskope-examples/examples/npa/browser-app

export NETSKOPE_SERVER_URL="https://your-tenant.goskope.com/api/v2"
export NETSKOPE_API_KEY="your-api-token"

terraform init && terraform apply
```

For detailed setup instructions, see the [Quick Start guide](./getting-started/quick-start.md).

## Prerequisites

- Netskope tenant with REST API v2 access ([setup guide](./getting-started/quick-start.md#step-1-create-an-api-key))
- Terraform >= 1.0
- Product-specific licenses: NPA, DNS Security, or IPSec as needed
- For AWS examples: AWS CLI configured with appropriate permissions

## Resources

- [Netskope Terraform Provider](https://registry.terraform.io/providers/netskopeoss/netskope/latest) - Terraform Registry
- [Provider Documentation](https://registry.terraform.io/providers/netskopeoss/netskope/latest/docs) - Resources and data sources
- [Netskope Documentation](https://docs.netskope.com) - Product documentation

---

[Contributing](./CONTRIBUTING.md) | [License](./LICENSE) (Apache 2.0)
